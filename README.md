<div align="center">
  <img src="https://raw.githubusercontent.com/lupodevelop/cowl/main/assets/img/logo.png" alt="cowl logo" width="200" />
</div>

[![Package Version](https://img.shields.io/hexpm/v/cowl)](https://hex.pm/packages/cowl) [![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/cowl/) [![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/lupodevelop/cowl/actions/workflows/test.yml/badge.svg)](https://github.com/lupodevelop/cowl/actions/workflows/test.yml) [![Built with Gleam](https://img.shields.io/badge/built%20with-gleam-ffaff3?logo=gleam)](https://gleam.run/)

# cowl

Type-safe secret masking for Gleam. Wrap passwords, API keys, and other
sensitive values in `Secret(a)` so they never appear in logs or debug output.

> The name comes from Batman's cowl, the mask that hides his true 
> identity. What if there was a cow under that cowl? Who knows?

---

## Install

```sh
gleam add cowl
```

---

## Quick start

```gleam
import cowl
import cowl/unsafe  // explicit danger zone — see below

// Wrap at the boundary.
let key = cowl.labeled("sk-abc123xyz789", "openai_key")
let tok = cowl.token("sk-abc123xyz789")   // smart peek masker built in

// Safe display — never the raw value.
cowl.mask(key)                                       // "***"
cowl.mask(tok)                                       // "sk-a...y789"
cowl.mask_with(key, cowl.Peek(cowl.Last(4), "...")) // "...y789"
cowl.field(key)                                      // #("openai_key", "***")

// Use the value inside a callback — it cannot escape.
cowl.with_secret(key, fn(raw) { send_request(raw) })

// Safe side effects — callback receives the masked string, not the raw value.
cowl.tap_masked(tok, fn(m) { logger.info("key: " <> m) })

// Raw extraction lives in cowl/unsafe — visible in every code review.
unsafe.reveal(key)
```

---

## The boundary principle

Cowl splits operations into two zones:

- **`cowl`** — everything safe. No raw value ever leaves a callback.
- **`cowl/unsafe`** — touches the raw value directly. An `import cowl/unsafe`
  in production code is a code-review red flag by design.

---

## Constructors

| Constructor | Masker default | When to use |
| ----------- | -------------- | ----------- |
| `secret(v)` | `"***"` | Generic value, any type |
| `string(v)` | `"***"` | Explicit string variant of `secret` |
| `token(v)` | `Both(4,4)` peek | API keys and tokens |
| `new(v, masker)` | Custom function | Any type with explicit masking |
| `labeled(v, label)` | `"***"` | Named secret for structured logging |

---

## Masking strategies

`mask_with` accepts a `Strategy` and always operates on `Secret(String)`.
`mask` uses the secret's built-in masker (set at construction) or `"***"`.

```gleam
cowl.mask_with(s, cowl.Stars)                    // "***"
cowl.mask_with(s, cowl.Fixed("[redacted]"))       // "[redacted]"
cowl.mask_with(s, cowl.Label)                     // "[openai_key]"
cowl.mask_with(s, cowl.Peek(cowl.Both(3, 4), "...")) // "sk-...y789"
cowl.mask_with(s, cowl.Custom(string.uppercase))  // raw → transformed
```

> ⚠️ `Custom` receives the **raw** value. Use `tap_masked` for logging instead.

---

## Transformation

```gleam
// map — transforms the value, preserves label, drops masker (type changed).
cowl.secret("hunter2") |> cowl.map(string.length)  // Secret(Int)

// and_then — like map but for functions that return Secret. Inner masker carried forward.
cowl.secret("hunter2") |> cowl.and_then(fn(pw) { hash(pw) |> cowl.secret })

// map_label — rename label without touching value or masker.
cowl.labeled("tok", "old") |> cowl.map_label(string.uppercase)
```

---

## Loading from fallible sources

```gleam
import cowl
import envoy

envoy.get("OPENAI_API_KEY") |> cowl.labeled_from_result("openai_key")
// Result(Secret(String), envoy.NotFound)

dict.get(cfg, "db_pass") |> cowl.labeled_from_option("db_pass")
// Option(Secret(String))
```

---

## Structured logging

`field` and `field_with` return `#(String, String)` tuples for any
key-value logging API, including [`woof`](https://hex.pm/packages/woof).

```gleam
woof.info("request", [
  cowl.field(api_key),                                        // #("openai_key", "***")
  cowl.field_with(api_key, cowl.Peek(cowl.Last(4), "...")),  // #("openai_key", "...y789")
])
```

---

## Writing an adapter

Adapters must never import `cowl/unsafe`. Use `with_secret` only:

```gleam
pub fn bearer_auth(req: Request, token: Secret(String)) -> Request {
  cowl.with_secret(token, fn(raw) {
    req |> request.set_header("authorization", "Bearer " <> raw)
  })
}
```

---

## Note on `io.debug`

The value lives inside a closure — `io.debug`, `echo`, and `string.inspect`
print the closure reference, not the raw value. Use `cowl.to_string` for
safe debug output:

```gleam
io.debug(cowl.to_string(password))  // "Secret(***)"
```

---

## Migrating from 1.x

See [MIGRATION.md](MIGRATION.md).

---

Made with 💜 in [Gleam](https://gleam.run/). MIT — *cowl · lupodevelop · 2026*
