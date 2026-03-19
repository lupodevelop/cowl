/// Test suite for cowl.
///
/// Coverage targets:
///   - Construction: secret, labeled, with_label, get_label
///   - Masking: Stars, Fixed, Label, Peek (all modes + edge cases), Custom
///   - Extraction: reveal, use_secret
///   - Transformation: map, and_then
///   - Comparison: equal
///   - Debug: to_string
///   - Result helpers: from_result, labeled_from_result
///   - Option helpers: from_option, labeled_from_option
///   - Logging helpers: field, field_with
import cowl
import gleam/option.{type Option, None, Some}
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Construction and labels
// ---------------------------------------------------------------------------

pub fn secret_wraps_value_test() {
  cowl.secret("password")
  |> cowl.reveal
  |> should.equal("password")
}

pub fn secret_has_no_label_test() {
  cowl.secret("password")
  |> cowl.get_label
  |> should.equal(None)
}

pub fn labeled_attaches_label_test() {
  cowl.labeled("token", "api_key")
  |> cowl.get_label
  |> should.equal(Some("api_key"))
}

pub fn labeled_preserves_value_test() {
  cowl.labeled("token", "api_key")
  |> cowl.reveal
  |> should.equal("token")
}

pub fn with_label_adds_label_test() {
  cowl.secret("x")
  |> cowl.with_label("my_label")
  |> cowl.get_label
  |> should.equal(Some("my_label"))
}

pub fn with_label_replaces_existing_label_test() {
  cowl.labeled("x", "old")
  |> cowl.with_label("new")
  |> cowl.get_label
  |> should.equal(Some("new"))
}

// ---------------------------------------------------------------------------
// Labels — remove_label
// ---------------------------------------------------------------------------

pub fn remove_label_clears_existing_label_test() {
  cowl.labeled("token", "api_key")
  |> cowl.remove_label
  |> cowl.get_label
  |> should.equal(None)
}

pub fn remove_label_on_unlabeled_is_noop_test() {
  cowl.secret("token")
  |> cowl.remove_label
  |> cowl.get_label
  |> should.equal(None)
}

pub fn remove_label_preserves_value_test() {
  cowl.labeled("hunter2", "pw")
  |> cowl.remove_label
  |> cowl.reveal
  |> should.equal("hunter2")
}

// ---------------------------------------------------------------------------
// Masking — Stars (default)
// ---------------------------------------------------------------------------

pub fn mask_returns_stars_test() {
  cowl.secret("my-password123")
  |> cowl.mask
  |> should.equal("***")
}

pub fn mask_empty_string_returns_stars_test() {
  cowl.secret("")
  |> cowl.mask
  |> should.equal("***")
}

pub fn mask_with_stars_explicit_test() {
  cowl.secret("anything")
  |> cowl.mask_with(cowl.Stars)
  |> should.equal("***")
}

// ---------------------------------------------------------------------------
// Masking — Fixed
// ---------------------------------------------------------------------------

pub fn mask_with_fixed_returns_fixed_text_test() {
  cowl.secret("anything")
  |> cowl.mask_with(cowl.Fixed("[HIDDEN]"))
  |> should.equal("[HIDDEN]")
}

pub fn mask_with_fixed_ignores_value_test() {
  // The secret's value must never influence the Fixed output.
  cowl.secret("")
  |> cowl.mask_with(cowl.Fixed("[redacted]"))
  |> should.equal("[redacted]")
}

// ---------------------------------------------------------------------------
// Masking — Label
// ---------------------------------------------------------------------------

pub fn mask_with_label_uses_label_test() {
  cowl.labeled("token", "api_key")
  |> cowl.mask_with(cowl.Label)
  |> should.equal("[api_key]")
}

pub fn mask_with_label_falls_back_to_secret_test() {
  cowl.secret("token")
  |> cowl.mask_with(cowl.Label)
  |> should.equal("[secret]")
}

// ---------------------------------------------------------------------------
// Masking — Peek: First
// ---------------------------------------------------------------------------

pub fn peek_first_normal_test() {
  cowl.secret("abcdefgh")
  |> cowl.mask_with(cowl.Peek(cowl.First(4), "..."))
  |> should.equal("abcd...")
}

pub fn peek_first_custom_filler_test() {
  cowl.secret("abcdefgh")
  |> cowl.mask_with(cowl.Peek(cowl.First(4), "***"))
  |> should.equal("abcd***")
}

pub fn peek_first_n_equals_len_shows_all_test() {
  // Exactly at length — no filler appended.
  cowl.secret("abcd")
  |> cowl.mask_with(cowl.Peek(cowl.First(4), "..."))
  |> should.equal("abcd")
}

pub fn peek_first_n_exceeds_len_shows_all_test() {
  cowl.secret("abcd")
  |> cowl.mask_with(cowl.Peek(cowl.First(10), "..."))
  |> should.equal("abcd")
}

// ---------------------------------------------------------------------------
// Masking — Peek: Last
// ---------------------------------------------------------------------------

pub fn peek_last_normal_test() {
  cowl.secret("abcdefgh")
  |> cowl.mask_with(cowl.Peek(cowl.Last(4), "..."))
  |> should.equal("...efgh")
}

pub fn peek_last_custom_filler_test() {
  cowl.secret("abcdefgh")
  |> cowl.mask_with(cowl.Peek(cowl.Last(4), "***"))
  |> should.equal("***efgh")
}

pub fn peek_last_n_equals_len_shows_all_test() {
  cowl.secret("abcd")
  |> cowl.mask_with(cowl.Peek(cowl.Last(4), "..."))
  |> should.equal("abcd")
}

pub fn peek_last_n_exceeds_len_shows_all_test() {
  cowl.secret("abcd")
  |> cowl.mask_with(cowl.Peek(cowl.Last(10), "..."))
  |> should.equal("abcd")
}

// ---------------------------------------------------------------------------
// Masking — Peek: Both
// ---------------------------------------------------------------------------

pub fn peek_both_normal_test() {
  cowl.secret("abcdefgh")
  |> cowl.mask_with(cowl.Peek(cowl.Both(2, 3), "..."))
  |> should.equal("ab...fgh")
}

pub fn peek_both_custom_filler_test() {
  cowl.secret("abcdefgh")
  |> cowl.mask_with(cowl.Peek(cowl.Both(2, 3), "***"))
  |> should.equal("ab***fgh")
}

pub fn peek_both_n_plus_m_equals_len_shows_all_test() {
  // n + m == len — no filler inserted.
  cowl.secret("abcd")
  |> cowl.mask_with(cowl.Peek(cowl.Both(2, 2), "..."))
  |> should.equal("abcd")
}

pub fn peek_both_n_plus_m_exceeds_len_shows_all_test() {
  cowl.secret("abcd")
  |> cowl.mask_with(cowl.Peek(cowl.Both(3, 3), "..."))
  |> should.equal("abcd")
}

// ---------------------------------------------------------------------------
// Masking — Peek: empty string edge case
// ---------------------------------------------------------------------------

pub fn peek_empty_string_returns_filler_test() {
  // An empty secret returns the filler to signal that a value exists.
  cowl.secret("")
  |> cowl.mask_with(cowl.Peek(cowl.First(3), "..."))
  |> should.equal("...")
}

pub fn peek_empty_string_custom_filler_test() {
  cowl.secret("")
  |> cowl.mask_with(cowl.Peek(cowl.First(3), "***"))
  |> should.equal("***")
}

pub fn peek_last_empty_string_returns_filler_test() {
  cowl.secret("")
  |> cowl.mask_with(cowl.Peek(cowl.Last(3), "..."))
  |> should.equal("...")
}

pub fn peek_both_empty_string_returns_filler_test() {
  cowl.secret("")
  |> cowl.mask_with(cowl.Peek(cowl.Both(2, 2), "..."))
  |> should.equal("...")
}

// ---------------------------------------------------------------------------
// Masking — Custom (escape hatch)
// ---------------------------------------------------------------------------

pub fn mask_with_custom_transforms_value_test() {
  cowl.secret("hello")
  |> cowl.mask_with(cowl.Custom(string.uppercase))
  |> should.equal("HELLO")
}

pub fn mask_with_custom_receives_raw_value_test() {
  // Verify the function receives the actual secret value, not a masked form.
  cowl.secret("abc")
  |> cowl.mask_with(
    cowl.Custom(fn(v) { "len=" <> string.inspect(string.length(v)) }),
  )
  |> should.equal("len=3")
}

// ---------------------------------------------------------------------------
// Extraction: reveal
// ---------------------------------------------------------------------------

pub fn reveal_returns_original_string_test() {
  cowl.secret("hunter2")
  |> cowl.reveal
  |> should.equal("hunter2")
}

pub fn reveal_returns_original_int_test() {
  // Secret(a) is generic — it works with any type.
  cowl.secret(42)
  |> cowl.reveal
  |> should.equal(42)
}

// ---------------------------------------------------------------------------
// Extraction: use_secret
// ---------------------------------------------------------------------------

pub fn use_secret_passes_correct_value_test() {
  cowl.secret("hunter2")
  |> cowl.use_secret(fn(v) { v == "hunter2" })
  |> should.be_true()
}

pub fn use_secret_return_type_follows_callback_test() {
  // Return type is Int, not Secret — the value is consumed locally.
  cowl.secret("hello")
  |> cowl.use_secret(string.length)
  |> should.equal(5)
}

// ---------------------------------------------------------------------------
// Transformation: map
// ---------------------------------------------------------------------------

pub fn map_transforms_value_test() {
  cowl.secret("hello")
  |> cowl.map(string.length)
  |> cowl.reveal
  |> should.equal(5)
}

pub fn map_preserves_label_test() {
  cowl.labeled("hello", "greeting")
  |> cowl.map(string.uppercase)
  |> cowl.get_label
  |> should.equal(Some("greeting"))
}

pub fn map_value_stays_wrapped_test() {
  // After map the result is still a Secret — not a raw value.
  let s =
    cowl.secret("hello")
    |> cowl.map(string.uppercase)

  cowl.mask(s)
  |> should.equal("***")
}

// ---------------------------------------------------------------------------
// woof helpers: field
// ---------------------------------------------------------------------------

pub fn field_uses_label_as_key_test() {
  cowl.labeled("sk-abc123", "api_key")
  |> cowl.field
  |> should.equal(#("api_key", "***"))
}

pub fn field_falls_back_to_secret_key_test() {
  cowl.secret("sk-abc123")
  |> cowl.field
  |> should.equal(#("secret", "***"))
}

// ---------------------------------------------------------------------------
// woof helpers: field_with
// ---------------------------------------------------------------------------

pub fn field_with_peek_last_test() {
  cowl.labeled("abcdefgh", "api_key")
  |> cowl.field_with(cowl.Peek(cowl.Last(4), "..."))
  |> should.equal(#("api_key", "...efgh"))
}

pub fn field_with_fixed_test() {
  cowl.labeled("anything", "db_pass")
  |> cowl.field_with(cowl.Fixed("[redacted]"))
  |> should.equal(#("db_pass", "[redacted]"))
}

pub fn field_with_no_label_uses_secret_key_test() {
  cowl.secret("tok")
  |> cowl.field_with(cowl.Stars)
  |> should.equal(#("secret", "***"))
}

pub fn field_with_label_strategy_no_label_test() {
  // When no label and Label strategy: key="secret", value="[secret]".
  // Documented behaviour — avoid this combo: use Stars or Fixed instead.
  cowl.secret("tok")
  |> cowl.field_with(cowl.Label)
  |> should.equal(#("secret", "[secret]"))
}

// ---------------------------------------------------------------------------
// to_string — safe debug representation
// ---------------------------------------------------------------------------

pub fn to_string_masks_value_test() {
  cowl.secret("hunter2")
  |> cowl.to_string
  |> should.equal("Secret(***)")
}

pub fn to_string_with_label_still_masks_test() {
  cowl.labeled("sk-abc123", "openai_key")
  |> cowl.to_string
  |> should.equal("Secret(***)")
}

pub fn to_string_empty_value_test() {
  cowl.secret("")
  |> cowl.to_string
  |> should.equal("Secret(***)")
}

// ---------------------------------------------------------------------------
// Peek: negative n edge cases
// ---------------------------------------------------------------------------

pub fn peek_first_zero_n_returns_filler_test() {
  cowl.secret("abcde")
  |> cowl.mask_with(cowl.Peek(cowl.First(0), "..."))
  |> should.equal("...")
}

pub fn peek_first_negative_n_returns_filler_test() {
  cowl.secret("abcde")
  |> cowl.mask_with(cowl.Peek(cowl.First(-3), "***"))
  |> should.equal("***")
}

pub fn peek_last_zero_n_returns_filler_test() {
  cowl.secret("abcde")
  |> cowl.mask_with(cowl.Peek(cowl.Last(0), "..."))
  |> should.equal("...")
}

pub fn peek_last_negative_n_returns_filler_test() {
  cowl.secret("abcde")
  |> cowl.mask_with(cowl.Peek(cowl.Last(-2), "***"))
  |> should.equal("***")
}

pub fn peek_both_zero_n_returns_filler_test() {
  cowl.secret("abcde")
  |> cowl.mask_with(cowl.Peek(cowl.Both(0, 2), "..."))
  |> should.equal("...")
}

pub fn peek_both_negative_m_returns_filler_test() {
  cowl.secret("abcde")
  |> cowl.mask_with(cowl.Peek(cowl.Both(2, -1), "***"))
  |> should.equal("***")
}

// ---------------------------------------------------------------------------
// equal
// ---------------------------------------------------------------------------

pub fn equal_same_value_no_label_test() {
  cowl.equal(cowl.secret("hunter2"), cowl.secret("hunter2"))
  |> should.be_true()
}

pub fn equal_ignores_labels_test() {
  cowl.equal(cowl.labeled("hunter2", "a"), cowl.labeled("hunter2", "b"))
  |> should.be_true()
}

pub fn equal_different_values_test() {
  cowl.equal(cowl.secret("abc"), cowl.secret("xyz"))
  |> should.be_false()
}

pub fn equal_generic_type_test() {
  cowl.equal(cowl.secret(42), cowl.secret(42))
  |> should.be_true()
}

// ---------------------------------------------------------------------------
// from_result
// ---------------------------------------------------------------------------

pub fn from_result_ok_wraps_in_secret_test() {
  let result = Ok("hunter2")
  cowl.from_result(result)
  |> should.be_ok
  |> cowl.reveal
  |> should.equal("hunter2")
}

pub fn from_result_error_stays_error_test() {
  let result: Result(String, String) = Error("not found")
  cowl.from_result(result)
  |> should.be_error
  |> should.equal("not found")
}

pub fn from_result_ok_no_label_test() {
  Ok("tok")
  |> cowl.from_result
  |> should.be_ok
  |> cowl.get_label
  |> should.equal(None)
}

// ---------------------------------------------------------------------------
// labeled_from_result
// ---------------------------------------------------------------------------

pub fn labeled_from_result_ok_attaches_label_test() {
  Ok("sk-abc")
  |> cowl.labeled_from_result("openai_key")
  |> should.be_ok
  |> cowl.get_label
  |> should.equal(Some("openai_key"))
}

pub fn labeled_from_result_ok_preserves_value_test() {
  Ok("sk-abc")
  |> cowl.labeled_from_result("openai_key")
  |> should.be_ok
  |> cowl.reveal
  |> should.equal("sk-abc")
}

pub fn labeled_from_result_error_propagates_test() {
  let result: Result(String, String) = Error("missing env var")
  cowl.labeled_from_result(result, "api_key")
  |> should.be_error
  |> should.equal("missing env var")
}

// ---------------------------------------------------------------------------
// map_label & tap helpers
// ---------------------------------------------------------------------------

pub fn map_label_changes_label_test() {
  cowl.labeled("x", "old")
  |> cowl.map_label(fn(l) { "new-" <> l })
  |> cowl.get_label
  |> should.equal(Some("new-old"))
}

pub fn map_label_preserves_value_test() {
  cowl.labeled("x", "lbl")
  |> cowl.map_label(fn(_) { "irrelevant" })
  |> cowl.reveal
  |> should.equal("x")
}

pub fn tap_returns_same_secret_test() {
  let s = cowl.labeled("hi", "lbl")
  cowl.tap(s, fn(_) { 42 })
  |> cowl.equal(s)
  |> should.be_true()
}

pub fn tap_invokes_function_test() {
  // We use use_secret to observe the value inside side‑effect
  let called = cowl.tap(cowl.secret("z"), fn(v) { v == "z" })
  called |> cowl.reveal |> should.equal("z")
}

// ---------------------------------------------------------------------------
// Transformation: and_then
// ---------------------------------------------------------------------------

pub fn and_then_transforms_value_test() {
  cowl.secret("hello")
  |> cowl.and_then(fn(v) { cowl.secret(string.length(v)) })
  |> cowl.reveal
  |> should.equal(5)
}

pub fn and_then_preserves_outer_label_test() {
  cowl.labeled("hello", "greeting")
  |> cowl.and_then(fn(v) { cowl.secret(string.uppercase(v)) })
  |> cowl.get_label
  |> should.equal(Some("greeting"))
}

pub fn and_then_discards_inner_label_test() {
  // The inner secret's label is replaced by the outer's.
  cowl.labeled("hello", "outer")
  |> cowl.and_then(fn(v) { cowl.labeled(string.uppercase(v), "inner") })
  |> cowl.get_label
  |> should.equal(Some("outer"))
}

pub fn and_then_value_stays_wrapped_test() {
  let s =
    cowl.secret("hello")
    |> cowl.and_then(fn(v) { cowl.secret(string.uppercase(v)) })
  cowl.mask(s)
  |> should.equal("***")
}

pub fn and_then_no_label_preserved_test() {
  cowl.secret("x")
  |> cowl.and_then(fn(v) { cowl.labeled(v, "inner") })
  |> cowl.get_label
  |> should.equal(None)
}

// ---------------------------------------------------------------------------
// Option helpers: from_option
// ---------------------------------------------------------------------------

pub fn from_option_some_wraps_in_secret_test() {
  Some("hunter2")
  |> cowl.from_option
  |> should.be_some
  |> cowl.reveal
  |> should.equal("hunter2")
}

pub fn from_option_none_stays_none_test() {
  let opt: Option(String) = None
  cowl.from_option(opt)
  |> should.equal(None)
}

pub fn from_option_some_no_label_test() {
  Some("tok")
  |> cowl.from_option
  |> should.be_some
  |> cowl.get_label
  |> should.equal(None)
}

// ---------------------------------------------------------------------------
// Option helpers: labeled_from_option
// ---------------------------------------------------------------------------

pub fn labeled_from_option_some_attaches_label_test() {
  Some("sk-abc")
  |> cowl.labeled_from_option("openai_key")
  |> should.be_some
  |> cowl.get_label
  |> should.equal(Some("openai_key"))
}

pub fn labeled_from_option_some_preserves_value_test() {
  Some("sk-abc")
  |> cowl.labeled_from_option("openai_key")
  |> should.be_some
  |> cowl.reveal
  |> should.equal("sk-abc")
}

pub fn labeled_from_option_none_stays_none_test() {
  let opt: Option(String) = None
  cowl.labeled_from_option(opt, "api_key")
  |> should.equal(None)
}
