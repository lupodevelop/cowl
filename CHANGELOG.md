# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

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

