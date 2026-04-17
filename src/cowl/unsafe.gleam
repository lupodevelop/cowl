/// Unsafe operations on secrets.
///
/// Importing this module is an explicit signal - to reviewers, linters, and
/// future maintainers - that the surrounding code deliberately breaks the
/// secret boundary. Every function here touches the raw value directly.
///
/// **Rules for using `cowl/unsafe`:**
/// 1. Never import it in production application logic.
/// 2. Acceptable uses: unit tests, legacy interop, one-time migration scripts.
/// 3. Treat every `import cowl/unsafe` line as a code-review red flag.
///
/// If you need the value for a request, hash, or comparison, use
/// `cowl.with_secret` instead - it keeps the raw value contained.
import cowl.{type Secret}

/// Extract the raw value from a secret.
///
/// Once the value is in a plain variable the compiler can no longer protect
/// it. Keep the scope as small as possible and never assign it to a field
/// that outlives the current function.
///
/// Prefer `cowl.with_secret` for all production use.
pub fn reveal(secret: Secret(a)) -> a {
  cowl.with_secret(secret, fn(v) { v })
}

/// Run `f` on the raw value for its side effects; return the original secret.
///
/// ⚠️ Passing a logging or print function here will expose the secret in
/// plain text. This function exists for low-level debugging and test
/// instrumentation only.
///
/// For safe side effects use `cowl.tap_masked` instead.
pub fn tap_raw(secret: Secret(a), f: fn(a) -> b) -> Secret(a) {
  cowl.with_secret(secret, fn(v) {
    let _ = f(v)
    secret
  })
}
