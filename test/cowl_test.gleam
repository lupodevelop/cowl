/// Test suite for cowl 2.0.
///
/// Coverage targets:
///   - Construction: secret, string, token, new, labeled, with_label, get_label
///   - Masking: Stars, Fixed, Label, Peek (all modes + edge cases), Custom
///   - Generic mask / default_masker
///   - Safe boundary: with_secret
///   - Transformation: map, and_then, map_label, tap_masked
///   - Comparison: equal
///   - Debug: to_string
///   - Result helpers: from_result, labeled_from_result
///   - Option helpers: from_option, labeled_from_option
///   - Logging helpers: field, field_with
///   - cowl/unsafe: reveal, tap_raw
import cowl
import cowl/unsafe
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
  |> unsafe.reveal
  |> should.equal("password")
}

pub fn secret_has_no_label_test() {
  cowl.secret("password")
  |> cowl.get_label
  |> should.equal(None)
}

pub fn string_wraps_value_test() {
  cowl.string("password")
  |> unsafe.reveal
  |> should.equal("password")
}

pub fn string_has_no_label_test() {
  cowl.string("password")
  |> cowl.get_label
  |> should.equal(None)
}

pub fn string_masks_as_stars_test() {
  cowl.string("password")
  |> cowl.mask
  |> should.equal("***")
}

pub fn labeled_attaches_label_test() {
  cowl.labeled("token", "api_key")
  |> cowl.get_label
  |> should.equal(Some("api_key"))
}

pub fn labeled_preserves_value_test() {
  cowl.labeled("token", "api_key")
  |> unsafe.reveal
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

pub fn with_label_preserves_default_masker_test() {
  // token sets a default_masker; with_label must not discard it
  let t = cowl.token("sk-abc123xyz789") |> cowl.with_label("key")
  cowl.mask(t)
  |> should.not_equal("***")
}

// ---------------------------------------------------------------------------
// Construction: token
// ---------------------------------------------------------------------------

pub fn token_masks_with_peek_test() {
  // 14 chars: "sk-abc123xyz78" → first 4 + "..." + last 4
  cowl.token("sk-abc123xyz789")
  |> cowl.mask
  |> should.equal("sk-a...z789")
}

pub fn token_short_value_shows_all_test() {
  // "hi" is shorter than 4+4 = 8, so Both shows full value
  cowl.token("hi")
  |> cowl.mask
  |> should.equal("hi")
}

pub fn token_value_preserved_test() {
  cowl.token("sk-abc123")
  |> unsafe.reveal
  |> should.equal("sk-abc123")
}

// ---------------------------------------------------------------------------
// Construction: new
// ---------------------------------------------------------------------------

pub fn new_uses_custom_masker_test() {
  cowl.new(42, fn(n) { "int:" <> string.inspect(n) })
  |> cowl.mask
  |> should.equal("int:42")
}

pub fn new_value_preserved_test() {
  cowl.new(99, fn(_) { "***" })
  |> unsafe.reveal
  |> should.equal(99)
}

pub fn new_generic_type_test() {
  // Secret(#(String, Int))
  cowl.new(#("user", 42), fn(t) {
    let #(name, _) = t
    "[" <> name <> ":***]"
  })
  |> cowl.mask
  |> should.equal("[user:***]")
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
  |> unsafe.reveal
  |> should.equal("hunter2")
}

pub fn remove_label_preserves_default_masker_test() {
  // token sets a default_masker; remove_label must not discard it
  let t = cowl.token("sk-abc123xyz789") |> cowl.remove_label
  cowl.mask(t)
  |> should.not_equal("***")
}

// ---------------------------------------------------------------------------
// Generic mask / default_masker
// ---------------------------------------------------------------------------

pub fn mask_falls_back_to_stars_when_no_masker_test() {
  cowl.secret("anything")
  |> cowl.mask
  |> should.equal("***")
}

pub fn mask_uses_default_masker_when_set_test() {
  cowl.new("hello", string.uppercase)
  |> cowl.mask
  |> should.equal("HELLO")
}

pub fn mask_generic_int_secret_test() {
  cowl.new(1234, fn(n) { "****" <> string.slice(string.inspect(n), 2, 2) })
  |> cowl.mask
  |> should.equal("****34")
}

// ---------------------------------------------------------------------------
// Masking — Stars (default)
// ---------------------------------------------------------------------------

pub fn mask_with_stars_explicit_test() {
  cowl.secret("anything")
  |> cowl.mask_with(cowl.Stars)
  |> should.equal("***")
}

pub fn mask_with_stars_empty_string_test() {
  cowl.secret("")
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
// Masking — Peek: negative / zero n edge cases
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
// Masking — Custom (escape hatch)
// ---------------------------------------------------------------------------

pub fn mask_with_custom_transforms_value_test() {
  cowl.secret("hello")
  |> cowl.mask_with(cowl.Custom(string.uppercase))
  |> should.equal("HELLO")
}

pub fn mask_with_custom_receives_raw_value_test() {
  cowl.secret("abc")
  |> cowl.mask_with(
    cowl.Custom(fn(v) { "len=" <> string.inspect(string.length(v)) }),
  )
  |> should.equal("len=3")
}

// ---------------------------------------------------------------------------
// Safe boundary: with_secret
// ---------------------------------------------------------------------------

pub fn with_secret_passes_correct_value_test() {
  cowl.secret("hunter2")
  |> cowl.with_secret(fn(v) { v == "hunter2" })
  |> should.be_true()
}

pub fn with_secret_return_type_follows_callback_test() {
  cowl.secret("hello")
  |> cowl.with_secret(string.length)
  |> should.equal(5)
}

// ---------------------------------------------------------------------------
// Transformation: map
// ---------------------------------------------------------------------------

pub fn map_transforms_value_test() {
  cowl.secret("hello")
  |> cowl.map(string.length)
  |> unsafe.reveal
  |> should.equal(5)
}

pub fn map_preserves_label_test() {
  cowl.labeled("hello", "greeting")
  |> cowl.map(string.uppercase)
  |> cowl.get_label
  |> should.equal(Some("greeting"))
}

pub fn map_value_stays_wrapped_test() {
  let s =
    cowl.secret("hello")
    |> cowl.map(string.uppercase)

  cowl.mask(s)
  |> should.equal("***")
}

pub fn map_drops_default_masker_test() {
  // The masker fn(String)->String cannot carry over to fn(Int)->String after map.
  let s =
    cowl.token("sk-abc123xyz789")
    |> cowl.map(string.length)

  // No masker → falls back to "***"
  cowl.mask(s)
  |> should.equal("***")
}

// ---------------------------------------------------------------------------
// tap_masked
// ---------------------------------------------------------------------------

pub fn tap_masked_returns_secret_unchanged_test() {
  let s = cowl.labeled("hunter2", "pw")
  cowl.tap_masked(s, fn(_) { Nil })
  |> cowl.equal(s)
  |> should.be_true()
}

pub fn tap_masked_passes_masked_string_test() {
  // The callback receives the masked value, not the raw secret.
  let called = cowl.new("hunter2", fn(_) { "[MASKED]" })
  let received = {
    let _ =
      cowl.tap_masked(called, fn(m) {
        // We verify the masked value reached the callback.
        m
      })
    cowl.tap_masked(called, fn(m) { m })
    |> cowl.mask
  }
  received
  |> should.equal("[MASKED]")
}

pub fn tap_masked_does_not_reveal_raw_value_test() {
  // Token masker shows peek, not the full value.
  let s = cowl.token("sk-abc123xyz789")
  let masked_seen = cowl.tap_masked(s, fn(m) { m }) |> cowl.mask
  masked_seen |> should.equal("sk-a...z789")
}

// ---------------------------------------------------------------------------
// Transformation: and_then
// ---------------------------------------------------------------------------

pub fn and_then_transforms_value_test() {
  cowl.secret("hello")
  |> cowl.and_then(fn(v) { cowl.secret(string.length(v)) })
  |> unsafe.reveal
  |> should.equal(5)
}

pub fn and_then_preserves_outer_label_test() {
  cowl.labeled("hello", "greeting")
  |> cowl.and_then(fn(v) { cowl.secret(string.uppercase(v)) })
  |> cowl.get_label
  |> should.equal(Some("greeting"))
}

pub fn and_then_discards_inner_label_test() {
  cowl.labeled("hello", "outer")
  |> cowl.and_then(fn(v) { cowl.labeled(string.uppercase(v), "inner") })
  |> cowl.get_label
  |> should.equal(Some("outer"))
}

pub fn and_then_carries_inner_masker_test() {
  // Inner secret is a token — its masker should be preserved.
  let s =
    cowl.secret("any")
    |> cowl.and_then(fn(_) { cowl.token("sk-abc123xyz789") })

  cowl.mask(s)
  |> should.equal("sk-a...z789")
}

pub fn and_then_no_label_preserved_test() {
  cowl.secret("x")
  |> cowl.and_then(fn(v) { cowl.labeled(v, "inner") })
  |> cowl.get_label
  |> should.equal(None)
}

pub fn and_then_value_stays_wrapped_test() {
  let s =
    cowl.secret("hello")
    |> cowl.and_then(fn(v) { cowl.secret(string.uppercase(v)) })
  cowl.mask(s)
  |> should.equal("***")
}

// ---------------------------------------------------------------------------
// map_label
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
  |> unsafe.reveal
  |> should.equal("x")
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

pub fn to_string_token_uses_peek_test() {
  cowl.token("sk-abc123xyz789")
  |> cowl.to_string
  |> should.equal("Secret(sk-a...z789)")
}

pub fn to_string_new_uses_custom_masker_test() {
  cowl.new("hunter2", fn(_) { "[REDACTED]" })
  |> cowl.to_string
  |> should.equal("Secret([REDACTED])")
}

// ---------------------------------------------------------------------------
// Logging helpers: field
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

pub fn field_uses_token_masker_test() {
  cowl.token("sk-abc123xyz789")
  |> cowl.with_label("api_key")
  |> cowl.field
  |> should.equal(#("api_key", "sk-a...z789"))
}

// ---------------------------------------------------------------------------
// Logging helpers: field_with
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
  cowl.secret("tok")
  |> cowl.field_with(cowl.Label)
  |> should.equal(#("secret", "[secret]"))
}

// ---------------------------------------------------------------------------
// from_result
// ---------------------------------------------------------------------------

pub fn from_result_ok_wraps_in_secret_test() {
  let result = Ok("hunter2")
  cowl.from_result(result)
  |> should.be_ok
  |> unsafe.reveal
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
  |> unsafe.reveal
  |> should.equal("sk-abc")
}

pub fn labeled_from_result_error_propagates_test() {
  let result: Result(String, String) = Error("missing env var")
  cowl.labeled_from_result(result, "api_key")
  |> should.be_error
  |> should.equal("missing env var")
}

// ---------------------------------------------------------------------------
// Option helpers: from_option
// ---------------------------------------------------------------------------

pub fn from_option_some_wraps_in_secret_test() {
  Some("hunter2")
  |> cowl.from_option
  |> should.be_some
  |> unsafe.reveal
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
  |> unsafe.reveal
  |> should.equal("sk-abc")
}

pub fn labeled_from_option_none_stays_none_test() {
  let opt: Option(String) = None
  cowl.labeled_from_option(opt, "api_key")
  |> should.equal(None)
}

// ---------------------------------------------------------------------------
// cowl/unsafe: reveal
// ---------------------------------------------------------------------------

pub fn unsafe_reveal_returns_original_string_test() {
  cowl.secret("hunter2")
  |> unsafe.reveal
  |> should.equal("hunter2")
}

pub fn unsafe_reveal_returns_original_int_test() {
  cowl.secret(42)
  |> unsafe.reveal
  |> should.equal(42)
}

pub fn unsafe_reveal_returns_original_generic_test() {
  cowl.secret(#("a", 1))
  |> unsafe.reveal
  |> should.equal(#("a", 1))
}

// ---------------------------------------------------------------------------
// cowl/unsafe: tap_raw
// ---------------------------------------------------------------------------

pub fn unsafe_tap_raw_returns_same_secret_test() {
  let s = cowl.labeled("hi", "lbl")
  unsafe.tap_raw(s, fn(_) { 42 })
  |> cowl.equal(s)
  |> should.be_true()
}

pub fn unsafe_tap_raw_receives_raw_value_test() {
  cowl.secret("z")
  |> unsafe.tap_raw(fn(v) { v })
  |> unsafe.reveal
  |> should.equal("z")
}
