<div align="center">
  <img src="https://raw.githubusercontent.com/lupodevelop/cowl/main/assets/img/mask.png" alt="cowl logo" width="200" />
</div>


[![Package Version](https://img.shields.io/hexpm/v/cowl)](https://hex.pm/packages/cowl) [![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/cowl/) [![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/lupodevelop/cowl/actions/workflows/test.yml/badge.svg)](https://github.com/lupodevelop/cowl/actions/workflows/test.yml)   [![Built with Gleam](https://img.shields.io/badge/built%20with-gleam-ffaff3?logo=gleam)](https://gleam.run/)

# cowl

a Gleam library for securely handling sensitive data like passwords and API keys using opaque Secret types, preventing accidental exposure in logs and debugging output.



Hide passwords, API keys, and other sensitive values behind `Secret(a)` so
they never accidentally end up in a log line.

> The name comes from Batman's cowl the mask that hides who he is.

---

## Install

```sh
gleam add cowl
```

---

## Quick start

```gleam
import cowl
import envoy

// Wrap the moment you read it.
let key =
  envoy.get("OPENAI_API_KEY")
  |> cowl.labeled_from_result("openai_key")
// Result(Secret(String), envoy.NotFound)

// Or construct directly.
let key = cowl.labeled("sk-abc123xyz", "openai_key")

cowl.mask(key)                                      // "***"
cowl.mask_with(key, cowl.Peek(cowl.Last(4), "...")) // "...3xyz"
cowl.field(key)                                     // #("openai_key", "***")

// When you actually need the value, it's explicit.
cowl.use_secret(key, fn(raw) { send_request(raw) })
```

---

## Secrets

`Secret(a)` is an opaque type — nothing outside this module can unwrap it.
You can pass it around, store it in a record, or log it freely.

```gleam
let pw  = cowl.secret("hunter2")
let key = cowl.labeled("sk-abc123", "openai_key")

cowl.get_label(key)  // Some("openai_key")
cowl.get_label(pw)   // None

// Labels can be added or swapped later.
let key2 = cowl.with_label(key, "openai_key_v2")
```

---

## Masking strategies

### Stars (default)

```gleam
cowl.mask(cowl.secret("my-password"))  // "***"
```

### Fixed

```gleam
cowl.mask_with(secret, cowl.Fixed("[redacted]"))  // "[redacted]"
```

### Label

```gleam
cowl.labeled("token", "api_key") |> cowl.mask_with(cowl.Label)  // "[api_key]"
cowl.secret("token")             |> cowl.mask_with(cowl.Label)  // "[secret]"
```

### Peek

Show just enough to identify which value it is, without revealing it.

```gleam
let s = cowl.secret("sk-abc123xyz")

cowl.mask_with(s, cowl.Peek(cowl.First(4), "..."))   // "sk-a..."
cowl.mask_with(s, cowl.Peek(cowl.Last(4), "..."))    // "...3xyz"
cowl.mask_with(s, cowl.Peek(cowl.Both(3, 3), "...")) // "sk-...xyz"

// The filler is up to you.
cowl.mask_with(s, cowl.Peek(cowl.First(4), "***"))   // "sk-a***"
```

When the window is wider than the string, the full value is shown without
filler. Empty strings and non-positive windows (`n <= 0`) return the filler
alone.

### Custom

```gleam
cowl.mask_with(cowl.secret("hello"), cowl.Custom(string.uppercase))
// "HELLO"
```

---

## Extracting the value

### use_secret — preferred

The raw value is passed to a callback and never enters the return type. This
keeps it from propagating further through your codebase.

```gleam
let hash = cowl.use_secret(password, fn(raw) { bcrypt.hash(raw) })
// `raw` is gone — only the hash escapes
```

### reveal — when you really need it

`reveal` puts the raw value into a normal variable. Once it's out, the
compiler can no longer help you. Use it at the boundary where you actually
need the value (sending an HTTP request, verifying a hash, etc.) and keep
that scope as small as possible.

```gleam
let raw = cowl.reveal(db_password)
```

---

## map

Transform the value without unwrapping it. The label is preserved.

```gleam
cowl.secret("hunter2")
|> cowl.map(string.length)
|> cowl.reveal
// 7
```

### map_label

If you need to rename or modify a label but not the secret itself, use
`map_label`. It leaves the wrapped value untouched.

```gleam
cowl.labeled("tok", "old")
|> cowl.map_label(fn(l) { string.uppercase(l) })
|> cowl.get_label          // Some("OLD")
```

### tap

Run side effects with the secret's raw value while keeping it wrapped. This
is handy for logging, metrics, or any inspection where you want the original
`Secret` back.

> ⚠️ **Never pass a logging or print function directly** — it will output
> the secret in the clear.
>
> ```gleam
> // ✗ Leaks the value!
> cowl.tap(s, io.debug)
>
> // ✓ Safe
> cowl.tap(s, fn(_) { io.println(cowl.to_string(s)) })
> ```

```gleam
let s = cowl.secret("p")
cowl.tap(s, fn(v) { io.warn(v) })
// `s` is returned unchanged
```

---

## Logging integration

`field` and `field_with` return `#(String, String)` tuples ready for any
structured-logging API that accepts key-value pairs, including
[`woof`](https://github.com/lupodevelop/woof).

[![woof on hex.pm](https://img.shields.io/hexpm/v/woof?label=woof)](https://hex.pm/packages/woof)

```gleam
woof.info("request sent", [
  cowl.field(api_key),
  cowl.field_with(api_key, cowl.Peek(cowl.Last(4), "...")),
])
// openai_key=***
// openai_key=...3xyz
```

---

## Loading from any fallible source

`from_result` and `labeled_from_result` wrap the `Ok` value of any `Result`
directly — no intermediate `result.map` needed.

```gleam
import cowl
import envoy
import gleam/dict
import gleam/result

// Environment variables
envoy.get("OPENAI_API_KEY")
|> cowl.labeled_from_result("openai_api_key")
// Result(Secret(String), envoy.NotFound)

// Dict / config map
dict.get(cfg, "db_password")
|> cowl.labeled_from_result("db_password")
// Result(Secret(String), Nil)
```

`labeled_from_result` without a label is also available as `from_result`.

**Building a config struct** (example with [`envoy`](https://hex.pm/packages/envoy)):

[![envoy on hex.pm](https://img.shields.io/hexpm/v/envoy?label=envoy)](https://hex.pm/packages/envoy)
[![dotenv_gleam on hex.pm](https://img.shields.io/hexpm/v/dotenv_gleam?label=dotenv_gleam)](https://hex.pm/packages/dotenv_gleam)

```gleam
import cowl
import envoy
import gleam/result

pub type Config {
  Config(
    api_key: cowl.Secret(String),
    db_password: cowl.Secret(String),
  )
}

pub fn load_config() -> Result(Config, String) {
  use api_key <- result.try(
    envoy.get("OPENAI_API_KEY")
    |> cowl.labeled_from_result("openai_api_key")
    |> result.map_error(fn(_) { "Missing OPENAI_API_KEY" }),
  )
  use db_pass <- result.try(
    envoy.get("DB_PASSWORD")
    |> cowl.labeled_from_result("db_password")
    |> result.map_error(fn(_) { "Missing DB_PASSWORD" }),
  )
  Ok(Config(api_key: api_key, db_password: db_pass))
}
```

`cowl` doesn't load env vars itself — that's for [`envoy`](https://github.com/lpil/envoy),
[`dotenv_gleam`](https://github.com/nicklasxyz/dotenv_gleam), etc.

---

## equal

Compares two secrets by **value only** — labels are ignored.

In Gleam, `==` works on opaque types too, but it compares the full internal
struct. That means two secrets with the same value but different labels would
return `False` under `==`. `equal` does what you actually want:

```gleam
let a = cowl.labeled("hunter2", "old_label")
let b = cowl.labeled("hunter2", "new_label")

a == b             // False — labels differ
cowl.equal(a, b)  // True  — values are the same
```

Useful for checking a submitted password against a stored one:

```gleam
cowl.equal(stored_hash, cowl.secret(verify_hash(input)))
```

---

## API

| Function | Signature | Note |
|---|---|---|
| `secret` | `a -> Secret(a)` | No label |
| `labeled` | `(a, String) -> Secret(a)` | With label |
| `with_label` | `(Secret(a), String) -> Secret(a)` | Set/replace label |
| `remove_label` | `Secret(a) -> Secret(a)` | Clear label |
| `get_label` | `Secret(a) -> Option(String)` | |
| `equal` | `(Secret(a), Secret(a)) -> Bool` | Value equality, labels ignored |
| `from_result` | `Result(a, e) -> Result(Secret(a), e)` | Wrap `Ok` value |
| `labeled_from_result` | `(Result(a, e), String) -> Result(Secret(a), e)` | Wrap `Ok` value with label |
| `mask` | `Secret(String) -> String` | Stars |
| `mask_with` | `(Secret(String), Strategy) -> String` | |
| `to_string` | `Secret(String) -> String` | `"Secret(***)"` — safe for debug |
| `reveal` | `Secret(a) -> a` | Explicit extraction |
| `use_secret` | `(Secret(a), fn(a) -> b) -> b` | Callback, preferred |
| `map` | `(Secret(a), fn(a) -> b) -> Secret(b)` | Stay wrapped |
| `field` | `Secret(String) -> #(String, String)` | `#(label, "***")` for log entries |
| `field_with` | `(Secret(String), Strategy) -> #(String, String)` | Same, with explicit strategy |

Works on both Erlang/OTP and JavaScript targets.

---

## ⚠️ A note on `string.inspect` and `io.debug`

The value is stored **inside a closure**, so at runtime
`string.inspect`, `echo`, and `io.debug` print the closure reference instead
of the raw secret:

```gleam
// Prints: Secret(expose: //fn() { ... }, label: None)
io.debug(password)
```

To produce a safe, human-readable string use `cowl.to_string` or `cowl.mask`:

```gleam
// ✓ Safe — prints: "Secret(***)"
io.debug(cowl.to_string(password))
```

Note: `tap` receives the **raw value** as its argument, so passing a print
function directly still leaks it — always wrap with `cowl.to_string`.

---

Made with 💜 in [Gleam](https://gleam.run/).

MIT — *cowl · lupodevelop · 2026*
