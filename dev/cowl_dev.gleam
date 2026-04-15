/// cowl_dev — interactive playground for exploring the cowl library.
///
/// Run with:
///   gleam run -m cowl_dev
///
/// This file lives in /dev and is not included in the hex.pm package.
import cowl
import cowl/unsafe
import gleam/io
import gleam/option
import gleam/string

pub fn main() -> Nil {
  section("Construction")
  let pw = cowl.secret("hunter2")
  let key = cowl.labeled("sk-abc123xyz", "openai_key")
  let tok = cowl.token("sk-abc123xyz789")
  let custom = cowl.new(42, fn(n) { "int:" <> string.inspect(n) })

  io.println("unsafe.reveal pw  : " <> unsafe.reveal(pw))
  io.println("get_label         : " <> string.inspect(cowl.get_label(key)))
  io.println("to_string safe    : " <> cowl.to_string(pw))
  io.println("token mask        : " <> cowl.mask(tok))
  io.println("new(Int) mask     : " <> cowl.mask(custom))

  section("Masking")
  io.println("Stars             : " <> cowl.mask(key))
  io.println(
    "Fixed             : " <> cowl.mask_with(key, cowl.Fixed("[redacted]")),
  )
  io.println("Label             : " <> cowl.mask_with(key, cowl.Label))
  io.println(
    "Peek Last4        : "
    <> cowl.mask_with(key, cowl.Peek(cowl.Last(4), "...")),
  )
  io.println(
    "Peek First4       : "
    <> cowl.mask_with(key, cowl.Peek(cowl.First(4), "***")),
  )
  io.println(
    "Peek Both         : "
    <> cowl.mask_with(key, cowl.Peek(cowl.Both(3, 3), "...")),
  )
  io.println(
    "Custom            : "
    <> cowl.mask_with(cowl.secret("hello"), cowl.Custom(string.uppercase)),
  )

  section("Labels")
  let key2 = cowl.with_label(key, "openai_key_v2")
  io.println("with_label        : " <> string.inspect(cowl.get_label(key2)))
  let no_label = cowl.remove_label(key)
  io.println("remove_label      : " <> string.inspect(cowl.get_label(no_label)))
  let renamed =
    cowl.map_label(key, string.uppercase) |> cowl.get_label |> option.unwrap("")
  io.println("map_label         : " <> renamed)

  section("Safe boundary")
  let hash =
    cowl.with_secret(pw, fn(raw) {
      "len=" <> string.inspect(string.length(raw))
    })
  io.println("with_secret       : " <> hash)

  section("tap_masked")
  let _ =
    cowl.tap_masked(tok, fn(masked) {
      io.println("tap_masked saw    : " <> masked)
    })

  section("Transformation")
  let upper = cowl.map(pw, string.uppercase) |> unsafe.reveal
  io.println("map               : " <> upper)

  section("Equality")
  let a = cowl.labeled("hunter2", "old")
  let b = cowl.labeled("hunter2", "new")
  io.println("equal (val)       : " <> string.inspect(cowl.equal(a, b)))

  section("Result helpers")
  let ok_result: Result(String, String) = Ok("my-db-pass")
  let err_result: Result(String, String) = Error("not found")
  io.println(
    "from_result Ok    : "
    <> string.inspect(cowl.from_result(ok_result) |> result_to_masked),
  )
  io.println(
    "from_result Err   : " <> string.inspect(cowl.from_result(err_result)),
  )
  let labeled_ok =
    cowl.labeled_from_result(ok_result, "db_password")
    |> result_to_masked
  io.println("labeled_from_result: " <> string.inspect(labeled_ok))

  section("Logging helpers (field)")
  io.println("field             : " <> string.inspect(cowl.field(key)))
  io.println(
    "field_with        : "
    <> string.inspect(cowl.field_with(key, cowl.Peek(cowl.Last(4), "..."))),
  )

  section("Peek edge cases")
  io.println(
    "empty -> filler   : "
    <> cowl.mask_with(cowl.secret(""), cowl.Peek(cowl.First(3), "...")),
  )
  io.println(
    "n=0   -> filler   : "
    <> cowl.mask_with(cowl.secret("abc"), cowl.Peek(cowl.First(0), "...")),
  )
  io.println(
    "n>len  -> all     : "
    <> cowl.mask_with(cowl.secret("abc"), cowl.Peek(cowl.First(99), "...")),
  )

  section("cowl/unsafe (dev only)")
  let raw = unsafe.reveal(pw)
  io.println("unsafe.reveal     : " <> raw)
  let _ = unsafe.tap_raw(pw, fn(v) { io.println("unsafe.tap_raw    : " <> v) })
  Nil
}

fn section(title: String) -> Nil {
  io.println("")
  io.println("=== " <> title <> " ===")
}

fn result_to_masked(r: Result(cowl.Secret(String), e)) -> Result(String, e) {
  case r {
    Ok(s) -> Ok(cowl.mask(s))
    Error(e) -> Error(e)
  }
}
