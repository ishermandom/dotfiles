---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Rust style guide

- **Set the line width to 80-col**, with `max_width = 80` in `rustfmt.toml`
- **Prefer thin binaries**: A typical binary should handle input and output, and
  leave the rest of the implementation to the library, where it can be tested.
- **Write every test under `tests/`**, never in a `#[cfg(test)] mod tests`
  beside the code: Follow testing.md's preference to test via the public
  interface rather than reaching into private implementation details.
- **Prefer to fix the code rather than silencing lint findings**: escalate any
  exceptions to the user.
- **`expect` messages**: say what invariant should hold, in the style the
  standard library recommends —
  `.expect("a group should hold at least one card")`, not a bare noun phrase
  such as `.expect("one card")`. The message prints ahead of the error when the
  program panics, so it should read as the assumption that broke.
