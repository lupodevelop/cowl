import gleam/option.{type Option, None, Some}
import gleam/string

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

/// An opaque wrapper that keeps a value secret.
///
/// The value lives inside a closure, so `io.debug`, `echo`, and
/// `string.inspect` never reveal it. Use `cowl.to_string` for safe output.
pub opaque type Secret(a) {
  Secret(expose: fn() -> a, label: Option(String))
}

/// How to render a secret as text.
pub type Strategy {
  /// Always `"***"`.
  Stars

  /// A fixed replacement string; the secret value is ignored.
  Fixed(text: String)

  /// The label in brackets, or `"[secret]"` if no label is set.
  Label

  /// Show a small window of the secret with filler around it.
  Peek(mode: PeekMode, filler: String)

  /// Apply an arbitrary function to the raw value.
  ///
  /// ⚠️ The function receives the raw secret value. Never pass a logging
  /// function directly — it will expose the secret. Use a pure transform only.
  Custom(f: fn(String) -> String)
}

/// Selects which characters to expose in a `Peek` strategy.
pub type PeekMode {
  /// First `n` characters, then the filler.
  First(n: Int)
  /// Filler, then the last `n` characters.
  Last(n: Int)
  /// First `n` characters, filler, then the last `m`.
  Both(n: Int, m: Int)
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

/// Wrap `value` as a secret with no label.
pub fn secret(value: a) -> Secret(a) {
  Secret(expose: fn() { value }, label: None)
}

/// Wrap `value` as a secret with a `label`.
pub fn labeled(value: a, label: String) -> Secret(a) {
  Secret(expose: fn() { value }, label: Some(label))
}

/// Set or replace the label on a secret.
pub fn with_label(secret: Secret(a), label: String) -> Secret(a) {
  Secret(expose: secret.expose, label: Some(label))
}

/// Remove the label from a secret. The value is untouched.
pub fn remove_label(secret: Secret(a)) -> Secret(a) {
  Secret(expose: secret.expose, label: None)
}

/// Return the label, if any.
pub fn get_label(secret: Secret(a)) -> Option(String) {
  secret.label
}

// ---------------------------------------------------------------------------
// Masking
// ---------------------------------------------------------------------------

/// Render a string secret as `"***"`.
pub fn mask(secret: Secret(String)) -> String {
  mask_with(secret, Stars)
}

/// Render a string secret using the given strategy.
pub fn mask_with(secret: Secret(String), strategy: Strategy) -> String {
  case strategy {
    Stars -> "***"
    Fixed(text) -> text
    Label ->
      case secret.label {
        Some(l) -> "[" <> l <> "]"
        None -> "[secret]"
      }
    Peek(mode, filler) -> apply_peek(secret.expose(), mode, filler)
    Custom(f) -> f(secret.expose())
  }
}

/// A safe debug string — always `"Secret(***)"`, never the actual value.
pub fn to_string(secret: Secret(String)) -> String {
  "Secret(" <> mask(secret) <> ")"
}

fn apply_peek(value: String, mode: PeekMode, filler: String) -> String {
  let len = string.length(value)
  case len {
    0 -> filler
    _ ->
      case mode {
        First(n) ->
          peek_part(n, len, value, filler, fn() {
            string.slice(value, 0, n) <> filler
          })
        Last(n) ->
          peek_part(n, len, value, filler, fn() {
            filler <> string.slice(value, len - n, n)
          })
        Both(n, m) ->
          case n <= 0 || m <= 0 {
            True -> filler
            False ->
              case n + m >= len {
                True -> value
                False ->
                  string.slice(value, 0, n)
                  <> filler
                  <> string.slice(value, len - m, m)
              }
          }
      }
  }
}

fn peek_part(
  n: Int,
  len: Int,
  value: String,
  filler: String,
  build: fn() -> String,
) -> String {
  case n <= 0 {
    True -> filler
    False ->
      case n >= len {
        True -> value
        False -> build()
      }
  }
}

// ---------------------------------------------------------------------------
// Comparison
// ---------------------------------------------------------------------------

/// Compare two secrets by value — labels are ignored.
pub fn equal(a: Secret(a), b: Secret(a)) -> Bool {
  a.expose() == b.expose()
}

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

/// Unwrap and return the raw value.
pub fn reveal(secret: Secret(a)) -> a {
  secret.expose()
}

/// Pass the raw value to `f` without letting it escape the return type.
pub fn use_secret(secret: Secret(a), f: fn(a) -> b) -> b {
  f(secret.expose())
}

// ---------------------------------------------------------------------------
// Transformation
// ---------------------------------------------------------------------------

/// Transform the wrapped value while keeping it secret. The label is preserved.
pub fn map(secret: Secret(a), f: fn(a) -> b) -> Secret(b) {
  Secret(expose: fn() { f(secret.expose()) }, label: secret.label)
}

/// Chain a transformation that itself returns a `Secret`, avoiding `Secret(Secret(b))`.
///
/// Unlike `map`, `f` returns a `Secret(b)` directly — useful when the
/// mapping function produces a secret of its own. The label of the outer
/// secret is preserved; the inner secret's label is discarded.
///
/// ```gleam
/// cowl.secret("hunter2")
/// |> cowl.and_then(fn(pw) { hash_password(pw) |> cowl.secret })
/// ```
pub fn and_then(secret: Secret(a), f: fn(a) -> Secret(b)) -> Secret(b) {
  let inner = f(secret.expose())
  Secret(expose: inner.expose, label: secret.label)
}

/// Transform only the label, leaving the value untouched.
pub fn map_label(secret: Secret(a), f: fn(String) -> String) -> Secret(a) {
  Secret(expose: secret.expose, label: case secret.label {
    Some(l) -> Some(f(l))
    None -> None
  })
}

/// Run `f` for its side effects and return the original secret unchanged.
///
/// ⚠️ Never pass a logging function directly — it will print the raw value.
/// Use `cowl.to_string` for a safe representation instead.
pub fn tap(secret: Secret(a), f: fn(a) -> b) -> Secret(a) {
  let _ = f(secret.expose())
  secret
}

// ---------------------------------------------------------------------------
// Result helpers
// ---------------------------------------------------------------------------

/// Wrap the `Ok` value of a `Result` as a secret, passing errors through.
pub fn from_result(res: Result(a, e)) -> Result(Secret(a), e) {
  case res {
    Ok(v) -> Ok(secret(v))
    Error(e) -> Error(e)
  }
}

/// Wrap the `Some` value of an `Option` as a secret, returning `None` unchanged.
pub fn from_option(opt: Option(a)) -> Option(Secret(a)) {
  case opt {
    Some(v) -> Some(secret(v))
    None -> None
  }
}

/// Like `from_option`, but also attaches a label.
pub fn labeled_from_option(opt: Option(a), label: String) -> Option(Secret(a)) {
  case opt {
    Some(v) -> Some(labeled(v, label))
    None -> None
  }
}

/// Like `from_result`, but also attaches a label.
pub fn labeled_from_result(
  res: Result(a, e),
  label: String,
) -> Result(Secret(a), e) {
  case res {
    Ok(v) -> Ok(labeled(v, label))
    Error(e) -> Error(e)
  }
}

// ---------------------------------------------------------------------------
// Logging helpers
// ---------------------------------------------------------------------------

/// Return `#(label, "***")` for structured logging. Falls back to `"secret"` if unlabeled.
pub fn field(secret: Secret(String)) -> #(String, String) {
  field_with(secret, Stars)
}

/// Like `field`, with an explicit masking strategy.
pub fn field_with(
  secret: Secret(String),
  strategy: Strategy,
) -> #(String, String) {
  let key = case secret.label {
    Some(l) -> l
    None -> "secret"
  }
  #(key, mask_with(secret, strategy))
}
