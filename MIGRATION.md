# Migration Guide — cowl 1.x → 2.0

This guide covers every breaking change in cowl 2.0 and shows the exact
one-to-one replacements.

---

## Overview of breaking changes

| What changed | 1.x | 2.0 |
| --- | --- | --- |
| Raw extraction | `cowl.reveal(s)` | `unsafe.reveal(s)` |
| Tap on raw value | `cowl.tap(s, f)` | `unsafe.tap_raw(s, f)` |
| Boundary callback | `cowl.use_secret(s, f)` | `cowl.with_secret(s, f)` |

Everything else is additive — existing code that does not use `reveal`,
`tap`, or `use_secret` compiles and behaves identically in 2.0.

---

## Step 1 — Add the `cowl/unsafe` import where needed

Any file that calls `reveal` or `tap` needs:

```gleam
import cowl/unsafe
```

Add this import at the top of those files. The compiler will tell you exactly
which files require it.

---

## Step 2 — Replace `cowl.reveal`

**Before:**

```gleam
let raw = cowl.reveal(secret)
```

**After:**

```gleam
import cowl/unsafe

let raw = unsafe.reveal(secret)
```

`unsafe.reveal` is semantically identical. The only difference is that it
now signals to every reader of the code that the raw value is being extracted.

> If you only need the value inside a function, prefer `cowl.with_secret`
> (see Step 4) — it is safer because the raw value cannot escape the callback.

---

## Step 3 — Replace `cowl.tap`

`tap` is split into two functions depending on your intent.

### Side effect on the raw value (same behaviour as 1.x `tap`)

**Before:**

```gleam
cowl.tap(secret, fn(raw) { log_to_audit_system(raw) })
```

**After:**

```gleam
import cowl/unsafe

unsafe.tap_raw(secret, fn(raw) { log_to_audit_system(raw) })
```

> ⚠️ Only use `tap_raw` when you genuinely need the raw value in the side
> effect. Most logging use cases should use `tap_masked` instead.

### Side effect on the masked value (new, recommended for logging)

If you were using `tap` with `cowl.to_string` to avoid leaking the value:

**Before:**

```gleam
cowl.tap(secret, fn(_) { io.println(cowl.to_string(secret)) })
```

**After:**

```gleam
cowl.tap_masked(secret, fn(masked) { io.println(masked) })
```

`tap_masked` passes the already-masked string to the callback. The raw value
never enters the function, so there is nothing to accidentally log.

---

## Step 4 — Replace `cowl.use_secret`

**Before:**

```gleam
cowl.use_secret(api_key, fn(raw) { send_request(raw) })
```

**After:**

```gleam
cowl.with_secret(api_key, fn(raw) { send_request(raw) })
```

Rename only. The semantics and type signature are identical.

---

## What you get for free (no migration needed)

These changes are additive or signature-widening — no call sites break.

### `mask` now works on any `Secret(a)`

```gleam
// 1.x — only Secret(String)
cowl.mask(cowl.secret("hunter2"))  // "***"

// 2.0 — also works on Secret(Int), Secret(MyRecord), etc.
cowl.mask(cowl.secret(42))         // "***"
cowl.mask(cowl.new(42, fn(n) { "int:***" }))  // "int:***"
```

### New constructors

```gleam
// token — smart partial-reveal masker, no config needed
cowl.token("sk-abc123xyz789") |> cowl.mask
// "sk-a...z789"

// new — explicit masker for any type
cowl.new(#("admin", "secret"), fn(pair) {
  let #(user, _) = pair
  "[" <> user <> ":***]"
}) |> cowl.mask
// "[admin:***]"

// string — type-constrained alias for secret
cowl.string("hunter2")  // identical to cowl.secret("hunter2")
```

### `tap_masked` — safe logging in a pipeline

```gleam
api_key
|> cowl.tap_masked(fn(masked) { logger.info("using key: " <> masked) })
|> make_request
```

### `to_string` and `field` now work on any `Secret(a)`

```gleam
cowl.to_string(cowl.secret(42))  // "Secret(***)"
cowl.field(cowl.new(42, fn(_) { "num:***" }))  // #("secret", "num:***")
```

---

## Checklist

- [ ] Add `import cowl/unsafe` to files that call `reveal` or `tap`
- [ ] Replace `cowl.reveal(s)` → `unsafe.reveal(s)`
- [ ] Replace `cowl.tap(s, f)` → `unsafe.tap_raw(s, f)` **or** `cowl.tap_masked(s, f)` (preferred for logging)
- [ ] Replace `cowl.use_secret(s, f)` → `cowl.with_secret(s, f)`
- [ ] Run `gleam build` — the compiler will catch any missed call sites
- [ ] Run `gleam test`

---

## Why these changes?

**`reveal` → `unsafe`**: A call to `reveal` in production code is a
potential data leak. Moving it behind an explicit import makes every such
call visible in code review without any tooling.

**`tap` → `unsafe.tap_raw` + `cowl.tap_masked`**: `tap` was the easiest
way to accidentally log a raw secret in a pipeline. Splitting it into an
unsafe version (for the rare case you genuinely need the raw value) and a
safe version (for logging the masked representation) removes that footgun.

**`use_secret` → `with_secret`**: Gleam's standard naming convention for
resource-scoping callbacks is `with_*` (e.g., `with_connection`,
`with_transaction`). `with_secret` communicates the boundary semantics more
clearly and fits the ecosystem better.
