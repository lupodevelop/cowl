# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.1] - 2026-04-17

### Fixed

- Minor documentation and comment wording improvements across README, migration guide, and source comments.

## [2.0.0] - 2026-04-12

### Security boundary — breaking changes

This release moves every operation that touches the raw secret value into a
dedicated `cowl/unsafe` module. An `import cowl/unsafe` line is now a visible
code-review signal that a module deliberately crosses the secret boundary.

#### Removed from `cowl`

- **`reveal`** — moved to `cowl/unsafe.reveal`. Call sites must add
  `import cowl/unsafe` and replace `cowl.reveal(s)` with `unsafe.reveal(s)`.
- **`tap`** — replaced by two purpose-specific functions:
  - `cowl/unsafe.tap_raw` — side effects on the raw value (dangerous, moved to unsafe).
  - `cowl.tap_masked` — side effects on the already-masked string (safe, stays in core).
- **`use_secret`** — renamed to `cowl.with_secret`. The new name follows the
  Gleam `with_*` convention and better communicates the boundary semantics.

#### Added

- **`cowl/unsafe` module** with `reveal` and `tap_raw`. Every function in
  this module receives the raw secret value and must never be used in
  production application logic.
- **`cowl.with_secret(secret, f)`** — canonical replacement for `use_secret`.
- **`cowl.tap_masked(secret, f)`** — runs `f` on the masked string, returns
  the secret unchanged. Safe to use with logging functions.
- **`cowl.token(value)`** — constructor for API tokens. Sets a smart
  `Both(4, 4)` peek masker by default, so `mask` shows `"sk-a...y789"`
  without any configuration.
- **`cowl.string(value)`** — type-constrained alias for `secret(value)`.
  Useful when you want the call site to document that the secret is a string.
- **`cowl.new(value, masker)`** — universal constructor that accepts any type
  and an explicit masker function. The masker is stored on the secret and
  called automatically by `mask`.

#### Changed

- **`Secret(a)` internal representation** now carries an optional
  `default_masker: Option(fn(a) -> String)`. This is an opaque change —
  existing construction and pattern-matching code is unaffected.
- **`cowl.mask`** signature widened from `Secret(String) -> String` to
  `Secret(a) -> String`. It now calls the `default_masker` when present,
  and falls back to `"***"` when absent. Existing call sites continue to
  work without changes.
- **`cowl.to_string`** signature widened from `Secret(String) -> String` to
  `Secret(a) -> String` for the same reason.
- **`cowl.field`** signature widened from `Secret(String) -> #(String, String)`
  to `Secret(a) -> #(String, String)`. The masked value uses `mask`, so
  `default_masker` is respected automatically.
- **`cowl.map`** no longer transfers the `default_masker` to the result
  because `fn(a) -> String` cannot apply to the new type `b`. Attach a new
  masker to the mapped secret via `new` or `token` if needed.
- **`cowl.and_then`** preserves the inner secret's `default_masker` (which
  already knows how to display `b`).
- **`cowl.with_label`**, **`cowl.remove_label`**, and **`cowl.map_label`**
  all preserve `default_masker` across the label operation.

### Migration

See [MIGRATION.md](MIGRATION.md) for a complete, line-by-line guide.

## [1.1.0] - 2026-03-19

### Added

- `and_then` for monadic chaining — avoids `Secret(Secret(b))` when the mapping
  function itself returns a `Secret`. The outer secret's label is preserved.
- `from_option` to lift `Some(v)` into `Some(Secret(v))`, returning `None` unchanged.
- `labeled_from_option` — like `from_option`, but attaches a label.

### Changed

- `Custom` strategy doc now includes an explicit warning that the function
  receives the raw secret value and must not be used for logging.
- Internal `apply_peek` refactored: guard logic for `First` and `Last` modes
  extracted into a private `peek_part` helper, eliminating triplication.

## [1.0.0] - 2026-03-06

### Added

- Complete secret‑wrapping API with optional labels (`Secret(a)`).
- Multiple masking strategies: `Stars`, `Fixed`, `Label`, `Peek`, `Custom`.
- Helpers for partially revealing values with `Peek` (first, last, both).
- `reveal`, `use_secret`, and `map` for working with wrapped values.
- `equal` function for value comparisons that ignore labels.
- `to_string` safe debug output that never shows the secret.
- `from_result`/`labeled_from_result` to lift `Ok` values into secrets.
- Structured logging helpers `field` and `field_with` (compatible with woof).
- `map_label` to transform or rename a secret's label without unwrapping.
- `tap` for running side‑effecting code on a secret while returning it.
- `remove_label` to strip a label from a secret without touching the value.
- `dev/cowl_dev.gleam` interactive playground (`gleam run -m cowl_dev`).
- Comprehensive test suite covering features and edge cases.
- Cross‑platform builds (Erlang and JS targets) and examples in README.

### Fixed

- `Peek` strategies now return the filler when requested window sizes are
  non‑positive instead of misbehaving.
- `Secret(a)` stores its value inside a closure so that `io.debug`, `echo`,
  and `string.inspect` never print the raw value at runtime.
