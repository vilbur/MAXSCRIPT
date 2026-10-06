# MaxScript Protected Identifiers

These rules apply to every MaxScript file.

## Mandatory identifier rule

Never use a MAXScript language reserved keyword or protected built-in identifier as a user-defined identifier.

This applies to:

- local and global variables;
- function names;
- positional and keyword parameters;
- struct members;
- rollout and UI control identifiers;
- loop variables;
- temporary variables;
- other user-defined names.

Choose descriptive alternatives such as `edit_poly_mod`, `stack_mod`, `target_mod`, `source_node`, or `target_node` instead of generic built-in names.

## Explicitly forbidden identifier: `modifier`

Do not use `modifier` as a user-defined identifier anywhere in MaxScript code.

`modifier` is a built-in MAX superclass identifier and must be treated as protected even though Autodesk does not list it among the language reserved keywords.

Forbidden examples:

```maxscript
local modifier = Edit_Poly()
function getSelection modifier = (...)
for modifier in obj.modifiers do (...)
```

Use names such as:

```maxscript
local edit_poly_mod = Edit_Poly()
function getSelection edit_poly_mod = (...)
for stack_mod in obj.modifiers do (...)
```

## MAXScript language reserved keywords

The following Autodesk MAXScript language keywords must never be used as variable names or other user-defined identifiers:

```text
about
and
animate
as
at
attributes
by
case
catch
collect
continue
coordsys
do
else
exit
fn
for
from
function
global
if
in
local
macroscript
mapped
max
not
of
off
on
or
parameters
persistent
plugin
rcmenu
return
rollout
set
struct
then
throw
to
tool
try
undo
utility
when
where
while
with
```

`from` is reserved even though Autodesk notes that it is currently unused.

## Predefined and reserved globals

Do not shadow MAXScript predefined globals, 3ds Max system globals, or MAXScript system globals with local variables or parameters, even where MAXScript technically permits local reuse.

Common predefined globals that must be treated as protected include:

```text
true
false
on
off
pi
e
red
green
blue
white
black
orange
yellow
brown
gray
x_axis
y_axis
z_axis
ok
undefined
unsupplied
dontcollect
silentValue
```

The complete set of system globals can vary with 3ds Max versions. If a proposed identifier looks like an existing MAXScript/3ds Max built-in, verify it before using it.

## Built-in classes, superclasses, interfaces, and constructors

Do not shadow built-in MAXScript/3ds Max class, superclass, interface, constructor, or core-interface names with user-defined variables or parameters.

This includes `modifier` and any other built-in identifier that would make code ambiguous or collide with MAXScript/3ds Max symbols.

When unsure, choose a more specific identifier instead of a generic name.

## Runtime collision check

When running inside 3ds Max, `globalVars.isGlobal #name` can be used as one signal that a candidate name already exists globally.

For built-in global variables, `globalVars.getTypeTag #name` can distinguish constant globals and system globals. Do not treat runtime checking as a substitute for this rules file: language keywords and built-in class/superclass names must also be avoided.

## Review requirement

Before delivering or updating any MaxScript code:

1. Review newly introduced variable, parameter, function, struct-member, and control names.
2. Check them against the reserved keyword list above.
3. Do not shadow predefined or system globals.
4. Do not shadow built-in class, superclass, interface, or constructor names.
5. Specifically search for user-defined uses of `modifier` and rename them before delivery.
6. Prefer descriptive role-based names over generic names that may collide with MAXScript symbols.

## Source basis

Reserved keyword list: Autodesk MAXScript Help, `Language Reserved Keywords`.

Predefined globals and reserved-global behavior: Autodesk MAXScript Help, `Predefined Globals` and `Reserved Global Variables`.
