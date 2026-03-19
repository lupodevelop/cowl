/// cowl_dev — playground interattivo per esplorare la libreria cowl.
///
/// Esegui con:
///   gleam run -m cowl_dev
///
/// Questo file vive in /dev e non viene incluso nella pubblicazione su hex.pm.
import cowl
import gleam/io
import gleam/option
import gleam/string

pub fn main() -> Nil {
  section("Costruzione")
  let pw = cowl.secret("hunter2")
  let key = cowl.labeled("sk-abc123xyz", "openai_key")

  io.println("reveal pw  : " <> cowl.reveal(pw))
  io.println("get_label  : " <> string.inspect(cowl.get_label(key)))
  io.println("io.debug safe: " <> cowl.to_string(pw))

  section("Masking")
  io.println("Stars      : " <> cowl.mask(key))
  io.println("Fixed      : " <> cowl.mask_with(key, cowl.Fixed("[redacted]")))
  io.println("Label      : " <> cowl.mask_with(key, cowl.Label))
  io.println(
    "Peek Last4 : " <> cowl.mask_with(key, cowl.Peek(cowl.Last(4), "...")),
  )
  io.println(
    "Peek First4: " <> cowl.mask_with(key, cowl.Peek(cowl.First(4), "***")),
  )
  io.println(
    "Peek Both  : " <> cowl.mask_with(key, cowl.Peek(cowl.Both(3, 3), "...")),
  )
  io.println(
    "Custom     : "
    <> cowl.mask_with(cowl.secret("hello"), cowl.Custom(string.uppercase)),
  )

  section("Labels")
  let key2 = cowl.with_label(key, "openai_key_v2")
  io.println("with_label : " <> string.inspect(cowl.get_label(key2)))
  let no_label = cowl.remove_label(key)
  io.println("remove_label: " <> string.inspect(cowl.get_label(no_label)))
  let renamed =
    cowl.map_label(key, string.uppercase) |> cowl.get_label |> option.unwrap("")
  io.println("map_label  : " <> renamed)

  section("Estrazione")
  let hash =
    cowl.use_secret(pw, fn(raw) { "len=" <> string.inspect(string.length(raw)) })
  io.println("use_secret : " <> hash)

  section("Trasformazione")
  let upper = cowl.map(pw, string.uppercase) |> cowl.reveal
  io.println("map        : " <> upper)
  let s = cowl.secret("z")
  let tapped = cowl.tap(s, fn(_) { Nil })
  io.println("tap returns: " <> string.inspect(cowl.equal(s, tapped)))

  section("Uguaglianza")
  let a = cowl.labeled("hunter2", "old")
  let b = cowl.labeled("hunter2", "new")
  io.println("equal (val): " <> string.inspect(cowl.equal(a, b)))

  section("Result helpers")
  let ok_result: Result(String, String) = Ok("my-db-pass")
  let err_result: Result(String, String) = Error("not found")
  io.println(
    "from_result Ok : "
    <> string.inspect(cowl.from_result(ok_result) |> result_to_masked),
  )
  io.println(
    "from_result Err: " <> string.inspect(cowl.from_result(err_result)),
  )
  let labeled_ok =
    cowl.labeled_from_result(ok_result, "db_password")
    |> result_to_masked
  io.println("labeled_from_result: " <> string.inspect(labeled_ok))

  section("Logging helpers (field)")
  io.println("field      : " <> string.inspect(cowl.field(key)))
  io.println(
    "field_with : "
    <> string.inspect(cowl.field_with(key, cowl.Peek(cowl.Last(4), "..."))),
  )

  section("Peek edge cases")
  io.println(
    "empty → filler: "
    <> cowl.mask_with(cowl.secret(""), cowl.Peek(cowl.First(3), "...")),
  )
  io.println(
    "n=0   → filler: "
    <> cowl.mask_with(cowl.secret("abc"), cowl.Peek(cowl.First(0), "...")),
  )
  io.println(
    "n>len  → all  : "
    <> cowl.mask_with(cowl.secret("abc"), cowl.Peek(cowl.First(99), "...")),
  )
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
