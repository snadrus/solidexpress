# SolidExpress voice intent schema

Defines the contract between ASR (whisper.cpp + GBNF) and the kernel interpreter (`sx::voice`). The phrase corpus in `phrases.json` and grammar in `commands.gbnf` must produce utterances that map to this schema.

## Intent object

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `kind` | enum | yes | See kinds below |
| `verb` | string | yes | Action within the kind (see verb tables) |
| `value` | float \| null | no | Numeric magnitude when spoken (e.g. `3`, `10`, `55`) |
| `unit` | enum \| null | no | `mm` \| `in` \| `deg` when spoken or implied by verb |
| `name` | string \| null | no | Variable / parameter name (`width`, `length`, …) |
| `expression` | string \| null | no | Free-form expression for `set_expr` (e.g. `width * 2`) |
| `raw_text` | string | yes | Normalized ASR transcript (lowercase, space-separated) |
| `confidence` | float | yes | ASR or interpreter confidence in `[0, 1]` |

Unset optional fields should be `null` in JSON / absent in C++ optional wrappers.

## Kinds

| Kind | Purpose |
|------|---------|
| `constraint` | Sketch / assembly geometric constraints and dimensions |
| `model` | Feature and body operations |
| `view` | Camera / display / section |
| `app` | Application chrome (undo, save, dialogs) |
| `variable` | Named parameters and expressions |
| `query` | Read-only questions (mass, help, …) |
| `unmatched` | Recognized speech that did not map to a known verb |

## Verbs by kind

### `constraint`

| Verb | Typical slots | Notes |
|------|---------------|-------|
| `horizontal` | — | Selected line/edge |
| `vertical` | — | Selected line/edge |
| `parallel` | — | Needs ≥2 entities |
| `perpendicular` | — | Needs ≥2 entities |
| `tangent` | — | Curve–curve or curve–line |
| `equal` | — | Equal length/radius |
| `coincident` | — | Point-on / flush |
| `concentric` | — | Circles/arcs |
| `distance` | `value`, `unit` | Dimension between entities |
| `angle` | `value`, `unit=deg` | Angular dimension |
| `radius` | `value`, `unit` | Radial dimension |
| `fix` | — | Fully constrain / lock |

### `model`

| Verb | Typical slots | Notes |
|------|---------------|-------|
| `fillet` | `value`, `unit` | Edge/face fillet |
| `chamfer` | `value`, `unit` | Edge chamfer |
| `shell` | `value`, `unit` | Wall thickness |
| `extrude` | `value`, `unit` | Depth |
| `revolve` | `value`, `unit=deg` | Angle (often 360) |
| `hole` | `value`, `unit` | Diameter / size |
| `mirror` | — | About plane/face |
| `hide` | — | Hide selection |
| `isolate` | — | Isolate selection |
| `show_all` | — | Unhide all |
| `delete` | — | Delete selection |

### `view`

| Verb | Notes |
|------|-------|
| `front` | Front orthographic |
| `top` | Top orthographic |
| `right` | Right orthographic |
| `iso` | Isometric |
| `zoom_fit` | Fit all / selection |
| `section` | Toggle / create section view |
| `ortho` | Orthographic projection |
| `perspective` | Perspective projection |

### `app`

| Verb | Notes |
|------|-------|
| `undo` | |
| `redo` | |
| `save` | |
| `cancel` | Dismiss dialog / escape |
| `ok` | Confirm dialog |

### `variable`

| Verb | Typical slots | Notes |
|------|---------------|-------|
| `set_var` | `name`, `value`, `unit?` | `set width to 55` |
| `set_expr` | `name`, `expression` | `set height to width times two` |

### `query`

| Verb | Notes |
|------|-------|
| `mass` | How heavy / mass |
| `volume` | Volume of selection/body |
| `area` | Surface / face area |
| `distance_between` | Measure between two selections |
| `help` | Voice / command help |

### `unmatched`

| Verb | Notes |
|------|-------|
| `none` | Fallback; keep `raw_text` for logging |

## Normalization rules

1. ASR output is lowercase ASCII; digits as spoken numerals may appear as digits (`3`) or words (`three`) — the interpreter accepts both; the corpus uses digits when a number is primary.
2. Units map: `millimeter(s)` / `mm` → `mm`; `inch(es)` / `in` → `in`; `degree(s)` / `deg` → `deg`.
3. Missing unit defaults to document length unit for linear slots; `angle` / `revolve` default to `deg`.
4. Phrases in `phrases.json` are the **canonical allowed transcripts** for constrained decoding; paraphrases share the same `(kind, verb, value, unit, name)` slots.

## Related files

| Path | Role |
|------|------|
| `docs/voice/phrases.json` | Golden phrase → slot examples |
| `docs/voice/commands.gbnf` | whisper.cpp constrained-decoding grammar |
| `docs/voice/validate_phrases.py` | Count / schema / GBNF sync check |
| `sxkernel/tests/data/voice_phrases.json` | Copy for Catch2 / kernel tests |
