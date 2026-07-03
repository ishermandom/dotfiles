---
paths:
  - "**/*.cjs"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript and JavaScript style guide

- `prettier` enforces formatting (2-space indentation, single quotes) —
  configured globally in `~/.prettierrc` and runs automatically on Stop
- Follow the Google TypeScript Style Guide unless these rules conflict — these
  rules take priority
- **Types**: prefer explicit types at public interfaces, exported functions, and
  complex return values; omit annotations where local inference is obvious.
- **Flags**: prefer discriminated unions over boolean configuration flags —
  boolean flags don't self-document at call sites and resist exhaustive checks.
- **Nullability**: use `undefined` for absent values unless `null` has distinct
  semantic meaning; never mix `null`, `undefined`, and optional properties in
  the same API.
- **Async / promises**: prefer `async`/`await` over nested promise chains; never
  leave a promise unhandled.
- **Minimize mutation scope**: prefer `const` by default; keep mutable state
  narrowly scoped; avoid shared mutable module state unless clearly justified.
- **Decompose complex regexes** (general rule in CLAUDE.md): bind each logical
  part to a named `const` string and compose via template literals in
  `new RegExp(...)`; name capture groups `(?<level>…)` so match sites read
  `match.groups.level`, not positional indices.
