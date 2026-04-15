import gleam/option.{type Option, None, Some}
import gleam/string

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

/// An opaque wrapper that keeps a value secret.
///
/// The value lives inside a closure, so `io.debug`, `echo`, and
/// `string.inspect` never reveal it.
///
/// An optional `default_masker` controls what `mask` returns when no explicit
/// `Strategy` is given. Constructors like `token` set a smart default;
/// `secret` and `labeled` leave it unset, falling back to `"***"`.
pub opaque type Secret(a) {
  Secret(
    expose: fn() -> a,
    label: Option(String),
    default_masker: Option(fn(a) -> String),
  )
}

/// How to render a string secret as text.
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

/// Wrap `value` as a secret with no label and no custom masker.
/// `mask` falls back to `"***"`.
pub fn secret(value: a) -> Secret(a) {
  Secret(expose: fn() { value }, label: None, default_masker: None)
}

/// Wrap a `String` value as a secret. Equivalent to `secret` but
/// constrains the type to `String` at the call site.
pub fn string(value: String) -> Secret(String) {
  Secret(expose: fn() { value }, label: None, default_masker: None)
}

/// Wrap an API token with a smart partial-reveal masker.
///
/// `mask` will show the first 4 and last 4 characters with `"..."` in
/// between — enough to identify a token without exposing it.
///
/// ```gleam
/// cowl.token("sk-abc123xyz789") |> cowl.mask
/// // "sk-a...y789"  (if len > 8)
/// ```
pub fn token(value: String) -> Secret(String) {
  Secret(
    expose: fn() { value },
    label: None,
    default_masker: Some(fn(v) { apply_peek(v, Both(4, 4), "...") }),
  )
}

/// Wrap `value` with an explicit `masker` function used by `mask`.
///
/// The masker receives the raw value and must return a safe string
/// representation. Never use a logging function as the masker.
pub fn new(value: a, masker: fn(a) -> String) -> Secret(a) {
  Secret(expose: fn() { value }, label: None, default_masker: Some(masker))
}

/// Wrap `value` as a secret with a `label`.
pub fn labeled(value: a, label: String) -> Secret(a) {
  Secret(expose: fn() { value }, label: Some(label), default_masker: None)
}

/// Set or replace the label on a secret. The value and masker are untouched.
pub fn with_label(secret: Secret(a), label: String) -> Secret(a) {
  Secret(
    expose: secret.expose,
    label: Some(label),
    default_masker: secret.default_masker,
  )
}

/// Remove the label from a secret. The value and masker are untouched.
pub fn remove_label(secret: Secret(a)) -> Secret(a) {
  Secret(
    expose: secret.expose,
    label: None,
    default_masker: secret.default_masker,
  )
}

/// Return the label, if any.
pub fn get_label(secret: Secret(a)) -> Option(String) {
  secret.label
}

// ---------------------------------------------------------------------------
// Masking
// ---------------------------------------------------------------------------

/// Render the secret as a safe string using its default masker.
///
/// - If a `default_masker` was set (e.g. via `token` or `new`), it is called.
/// - Otherwise returns `"***"`.
///
/// Use `mask_with` to apply an explicit `Strategy` at the call site.
pub fn mask(secret: Secret(a)) -> String {
  case secret.default_masker {
    Some(f) -> f(secret.expose())
    None -> "***"
  }
}

/// Render a string secret using the given strategy, ignoring any default masker.
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

/// A safe debug string — always `"Secret(***)"` or `"Secret(<masked>)"`.
/// Never reveals the actual value.
pub fn to_string(secret: Secret(a)) -> String {
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

/// Compare two secrets by value — labels and maskers are ignored.
pub fn equal(a: Secret(a), b: Secret(a)) -> Bool {
  a.expose() == b.expose()
}

// ---------------------------------------------------------------------------
// Safe boundary
// ---------------------------------------------------------------------------

/// Pass the raw value to `f` without letting it escape the return type.
///
/// This is the preferred way to consume a secret. The raw value is confined
/// to the callback scope and cannot propagate further through your code.
///
/// ```gleam
/// cowl.with_secret(api_key, fn(raw) { send_request(raw) })
/// ```
pub fn with_secret(secret: Secret(a), f: fn(a) -> b) -> b {
  f(secret.expose())
}

// ---------------------------------------------------------------------------
// Transformation
// ---------------------------------------------------------------------------

/// Transform the wrapped value while keeping it secret.
///
/// The label is preserved. The default masker is **not** transferred because
/// the masker type `fn(a) -> String` cannot apply to the new type `b`.
/// Attach a new masker via `new` or `token` if needed.
pub fn map(secret: Secret(a), f: fn(a) -> b) -> Secret(b) {
  Secret(
    expose: fn() { f(secret.expose()) },
    label: secret.label,
    default_masker: None,
  )
}

/// Chain a transformation that itself returns a `Secret`, avoiding `Secret(Secret(b))`.
///
/// The outer secret's label is preserved. The inner secret's default masker
/// is carried forward (since it already knows how to display `b`).
/// The inner secret's label is discarded.
///
/// ```gleam
/// cowl.secret("hunter2")
/// |> cowl.and_then(fn(pw) { hash_password(pw) |> cowl.secret })
/// ```
pub fn and_then(secret: Secret(a), f: fn(a) -> Secret(b)) -> Secret(b) {
  let inner = f(secret.expose())
  Secret(
    expose: inner.expose,
    label: secret.label,
    default_masker: inner.default_masker,
  )
}

/// Transform only the label, leaving the value and masker untouched.
pub fn map_label(secret: Secret(a), f: fn(String) -> String) -> Secret(a) {
  Secret(
    expose: secret.expose,
    label: case secret.label {
      Some(l) -> Some(f(l))
      None -> None
    },
    default_masker: secret.default_masker,
  )
}

/// Run `f` on the masked representation for its side effects; return the
/// original secret unchanged. Safe to use with logging functions.
///
/// ```gleam
/// api_key
/// |> cowl.tap_masked(fn(masked) { logger.info("key in use: " <> masked) })
/// |> make_request
/// ```
pub fn tap_masked(secret: Secret(a), f: fn(String) -> b) -> Secret(a) {
  let _ = f(mask(secret))
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
pub fn field(secret: Secret(a)) -> #(String, String) {
  field_with_string(secret, mask(secret))
}

/// Like `field`, with an explicit masking strategy. Requires `Secret(String)`.
pub fn field_with(
  secret: Secret(String),
  strategy: Strategy,
) -> #(String, String) {
  field_with_string(secret, mask_with(secret, strategy))
}

fn field_with_string(secret: Secret(a), masked: String) -> #(String, String) {
  let key = case secret.label {
    Some(l) -> l
    None -> "secret"
  }
  #(key, masked)
}
