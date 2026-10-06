# MaxScript Unit and Numeric Precision Safety

These rules apply whenever MaxScript reads, compares, converts, stores, displays, or modifies numeric values that represent scene units, distances, coordinates, angles, scales, thresholds, tolerances, or geometry measurements.

## Core rule

Backend calculations must preserve the original numeric value unless the requested operation explicitly requires a defined numeric transformation.

Do not introduce hidden rounding, truncation, quantization, snapping, clamping, epsilon values, or tolerance-based equality as a convenience.

## Forbidden hidden transformations

Do not silently apply any of these to correctness-critical values:

- `round`;
- `floor`;
- `ceil`;
- conversion to Integer when the source value is Float or Double;
- decimal-place truncation;
- string formatting followed by reparsing for computation;
- unit-display formatting used as backend data;
- hidden grid or step snapping;
- hidden minimum/maximum clamping;
- invented epsilon comparisons;
- invented "float precision tolerance";
- arbitrary constants such as `0.001`, `0.0001`, or similar values used to decide that two measurements are "equal enough" unless that tolerance is explicitly part of the feature contract.

## Exactness by default

If a feature says zero, equal, same level, exact distance, exact coordinate, exact angle, or exact threshold, treat that literally unless the design explicitly defines a tolerance.

Do not replace:

```text
value == target
```

with:

```text
abs(value - target) <= hidden_tolerance
```

without an explicit requirement.

Do not convert a non-zero value into zero because it is "very small".

Do not merge nearby values into one level merely because their difference is below an invented precision threshold.

## Explicit tolerance only

A tolerance is allowed only when the algorithm genuinely requires one and the tolerance is explicit.

When tolerance is required:

1. Give it a clear role-based name such as `position_tolerance`, `angle_tolerance`, or `weld_threshold`.
2. The value must come from the feature specification, user input, documented project setting, or another explicit contract.
3. Do not hide it inside a generic helper as a private default.
4. Pass it into lower-level functions explicitly when practical.
5. Keep the unit meaning clear.
6. Do not change its magnitude merely to make a failing case pass.
7. If zero tolerance is requested, do not substitute a small positive epsilon.

Bad:

```maxscript
function isSameLevel z_a z_b =
(
    abs(z_a - z_b) <= 0.001
)
```

when `0.001` was never specified.

Good when exact comparison is required:

```maxscript
function isSameLevel z_a z_b =
(
    z_a == z_b
)
```

Good when a tolerance is explicitly part of the contract:

```maxscript
function isSameLevel z_a z_b position_tolerance =
(
    abs(z_a - z_b) <= position_tolerance
)
```

## Unit conversion

- Preserve as much numeric precision as the underlying MAXScript/3ds Max numeric type provides.
- Convert units mathematically, not by formatting a value for display and parsing the text back.
- Do not round during unit conversion unless the user or feature specification explicitly requests rounding.
- Keep computational values separate from formatted UI strings.
- UI may display fewer decimal places for readability, but the backend value must remain unrounded.
- A spinner/display precision setting must not silently quantize the stored backend value unless that quantization is explicitly intended.

## Geometry and topology decisions

Precision rules are especially strict when numeric comparisons control:

- vertex alignment;
- edge classification;
- face/vertex/edge selection;
- welding;
- level detection;
- planarity checks;
- horizontal/vertical/skewed classification;
- intersection detection;
- distance grouping;
- topology rebuilding;
- destructive geometry edits.

A hidden tolerance in these decisions can change which geometry is selected or modified and is therefore a correctness bug unless explicitly specified.

## Audit requirement

When auditing MaxScript geometry or unit-sensitive code, actively search for:

- `round`, `floor`, `ceil`;
- Float-to-Integer conversion;
- hard-coded epsilon/tolerance constants;
- `abs(a - b) < ...` / `<= ...` comparisons;
- helper names containing `epsilon`, `precision`, `tolerance`, `snap`, `quantize`, or `round`;
- UI/display formatting values being reused for computation;
- implicit unit conversion through strings;
- thresholds not documented in the feature specification.

Report any hidden tolerance or rounding as a confirmed bug when it changes behavior and has no explicit design requirement.

## Delivery rule

Before delivering a change involving scene units, geometry coordinates, thresholds, or comparisons, verify that no hidden rounding or unapproved tolerance was introduced.

If a tolerance is necessary but the required value is not specified, do not invent one. Ask for the value or keep the operation exact where exact behavior is valid.
