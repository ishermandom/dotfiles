# Testing

## General

- **DAMP over DRY**: prioritize readability at the call site over avoiding repetition. Inline literal values — specific inputs, expected outputs, scripted replies — directly in each test. A reader should understand what is being tested without scrolling to a shared constant or fixture. Extract shared setup only when the exact value is genuinely irrelevant to the test's meaning.
- **I/O boundary testability**: entry points should be thin wrappers that delegate to a stream-accepting function. Tests call that function directly with in-memory streams — no temp files, no monkeypatching.
- **Test via public APIs**: exercise internal behaviors by constructing inputs that expose them at the public level, not by calling internals directly.
- **One behavior per test**
- **Test names read as sentences**: `test_expired_token_is_rejected`, not `test_auth`
- **Structure**: inputs → action → assertion; blank line between stages when it aids readability
- **Test input helpers**: prefer a typed struct with named fields and sensible defaults for irrelevant ones — hide construction ceremony, never hide what's being exercised. Add a bypass helper for error-handling tests rather than contorting the primary one.
- **Error cases**: assert both sides — no output produced *and* diagnostic emitted. Match a keyword, not the full message (exact text is an implementation detail).
- **`run_tests`**: every project includes an executable `run_tests` at the root. Resolve paths relative to the script (`$(dirname "$0")`), don't `cd`.

## Python

- pytest; `io.StringIO` for in-memory stream fakes
- Avoid `parametrize` unless it gives a concrete readability gain
- **Scripted fakes**: for dependencies with a fixed call sequence (LLM clients,
  HTTP, queues), a fake that holds a list of scripted replies consumed in order
  is more readable than mocks. Add `__enter__`/`__exit__` to assert all replies
  were consumed; `__exit__` should skip the check when an exception is already
  propagating to avoid masking the real failure.

## JavaScript

- `node:test` + `node:assert/strict` — built-in, no dependencies
- `--test-reporter=dot` for compact output
- Non-module source files (e.g. Google Apps Script): add `if (typeof module !== 'undefined') module.exports = { fn };` at the end to enable `require()` in tests
- `run_tests`: `exec node --test-reporter=dot "$(dirname "$0")/your_module.test.js"`
