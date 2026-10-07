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

## Required position precision contract

Any operation whose correctness depends on positions must take an explicit position-rounding precision from its caller. This applies when Point3/position values are used for:

- equality or inequality decisions;
- geometry identity or re-resolution;
- matching vertices/edges/faces by position;
- duplicate-position detection;
- grouping or bucketing positions;
- position-based topology lookup;
- expected-versus-actual move verification;
- other branching where tiny floating-point differences would otherwise change the result.

Canonical choices:

- `1mm`;
- `0.1mm`;
- `0.01mm` — default.

Unless a project explicitly extends this contract, do not invent additional position-precision values.

The reusable operation must receive the value explicitly, preferably as `position_precision` or `position_precision_mm`. A low-level reusable function must not silently read a UI control or private global to discover the precision. The UI/tool layer resolves the selected setting and passes it down.

The precision values are defined in millimeters regardless of the current 3ds Max system-unit setup. Convert the selected millimeter value to the active system-unit numeric value before applying it. Do not assume that literal `0.01` scene units means `0.01mm`.

For position equality/identity, quantize a temporary copy of each coordinate to the nearest multiple of the selected precision and compare those quantized copies. For example, conceptually:

```maxscript
function roundPositionToPrecision position_value position_precision =
(
    if position_precision <= 0.0 then return undefined

    [
        (round (position_value.x / position_precision)) * position_precision,
        (round (position_value.y / position_precision)) * position_precision,
        (round (position_value.z / position_precision)) * position_precision
    ]
)
```

The caller may resolve millimeters to current system units with an explicit unit conversion such as `units.decodeValue "0.01mm"`.

This is a deliberate, documented exception to the general no-hidden-rounding rule. It is not permission to round unrelated numeric calculations.

Important boundary:

- round/quantize temporary comparison or identity values;
- keep original backend Point3 values available for geometry operations and diagnostics;
- do not write the rounded position back to a vertex, node, modifier, or other scene geometry unless the requested operation explicitly performs snapping/quantization;
- do not replace this rounding contract with an arbitrary `abs(a - b) <= epsilon` test unless that operation separately defines tolerance-distance semantics.

For fatal expected-versus-actual position checks, log the raw expected value, raw actual value, rounded expected value, rounded actual value, and active position precision before failing.

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
