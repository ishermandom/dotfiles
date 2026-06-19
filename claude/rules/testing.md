---
paths:
  - "**/*test*"
---

# Testing

## General

- **DAMP over DRY**: prioritize readability at the call site over avoiding
  repetition. Inline literal values — specific inputs, expected outputs,
  scripted replies — directly in each test. Each test should be understandable
  without scrolling to a shared constant or fixture. Extract shared setup only
  when the exact value is genuinely irrelevant to the test's meaning. Before
  finalizing a test helper, verify that every value the test asserts on is
  visible in the test body, not inside the helper.
- **I/O boundary testability**: before writing a test that uses `tmp_path` or a
  real filesystem path, restructure the entry point to accept a stream instead —
  keep the entry point as a thin wrapper that opens the file and delegates, then
  test the inner function directly with in-memory streams. No temp files, no
  monkeypatching. For CLI entry points with file-input flags, use `-` as a
  sentinel (Unix convention) that redirects to an injectable `stdin` parameter —
  `main()` accepts `stdin: TextIO = sys.stdin`, and `-` routes to it. Tests pass
  `io.StringIO(...)` directly; argument parsing is exercised without temp files.
- **Test via public APIs**: exercise internal behaviors by constructing inputs
  that expose them at the public level, not by calling internals directly.
- **One behavior per test**
- **Test names read as sentences**: `test_expired_token_is_rejected`, not
  `test_auth`
- **Structure**: inputs → action → assertion; blank line between stages when it
  aids readability
- **Test input helpers**: name them `_make_foo` or `_build_foo`. Hide
  construction ceremony and irrelevant defaults; never hide the values under
  test. Builders accept native types and handle serialization internally —
  callers pass domain values, not wire-format strings or stream objects. Add a
  bypass helper for error-handling tests rather than contorting the primary one.
- **Only expose relevant parameters at call sites**: when many parameters don't
  affect the assertion, wrap the call under test in a helper that provides
  sensible defaults, so tests only spell out what they're actually testing. The
  wrapper must never hide a value the test asserts on — if a parameter matters
  to the assertion, pass it explicitly at the call site.
- **Error cases**: assert both sides — no output produced _and_ diagnostic
  emitted. Match a keyword, not the full message (exact text is an
  implementation detail).
- **`run_tests.sh`**: every project includes an executable `run_tests.sh` at the
  root. Resolve paths relative to the script (`$(dirname "$0")`), don't `cd`.

## Python

- **Test runner**: pytest; use `io.StringIO` for in-memory stream fakes
- **TDD stubs**: mark a not-yet-implemented test
  `@pytest.mark.xfail(strict=True)`. `strict=True` causes the suite to fail when
  the test unexpectedly passes — a reminder to remove the marker once the
  production code lands.
- **Comment non-obvious expectations**: add an inline comment when the reason an
  assertion is correct isn't apparent from the test name and assertion alone —
  e.g. when a count encodes a structural protocol, or a specific value reflects
  a design constraint.
- **Builder serialization**: `_make_foo` helpers convert Python values to the
  types the function under test expects — a `list[str]` becomes a JSON string or
  an `io.StringIO`; callers never serialize manually.
- **Avoid `parametrize`**: unless it gives a concrete readability gain
- **Scripted fakes**: for dependencies with a fixed call sequence (LLM clients,
  HTTP, queues), implement a fake that holds a list of scripted replies consumed
  in order — more readable than mocks. Add `__enter__`/`__exit__` to assert all
  replies were consumed; `__exit__` should skip the check when an exception is
  already propagating to avoid masking the real failure.
- **Varying scripted fake behavior**: pass different replies to the existing
  fake rather than creating a custom stub subclass — vary the inputs, not the
  fake. Reserve custom stubs for structural reasons (e.g. raising an exception
  the scripted fake can't raise).

## JavaScript

- **Test runner**: default to `node:test` + `node:assert/strict` — built-in, no
  dependencies — for pure logic and non-DOM code. Use **vitest + jsdom** instead
  when the code under test manipulates the DOM: vitest supplies a per-file DOM
  environment (`// @vitest-environment jsdom`) that `node:test` has no built-in
  answer for. Don't add vitest to a non-DOM project.
- **Reporter**: `--test-reporter=dot` for compact output
- **Non-module source files** (e.g. Google Apps Script): add
  `if (typeof module !== 'undefined') module.exports = { fn };` at the end to
  enable `require()` in tests
- **`run_tests.sh`**:
  `exec node --test-reporter=dot "$(dirname "$0")/your_module.test.js"` (a
  vitest project runs `exec npm --prefix "$(dirname "$0")/<pkg-dir>" test`
  instead)
