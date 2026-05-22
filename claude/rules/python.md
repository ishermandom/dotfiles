---
paths:
  - "**/*.py"
---

# Python style guide

- ruff enforces formatting (2-space indentation, single quotes); mypy enforces
  types — both configured globally in `~/.config/ruff/pyproject.toml` and run
  automatically on Stop
- **Prefer to follow the Google Python Style Guide** unless these rules conflict
  — these rules take priority
- **Prefer `if not foo:` over `if foo is None:`** for absent-content checks —
  unless `0`, `False`, or `[]` are valid non-absent values that must be
  distinguished from `None`
- **Prefer `@dataclass(frozen=True)` for multiple return values**: use it over
  bare tuples when returning multiple values from a function. Frozen dataclasses
  are immutable, named, and don't expose confusing positional access.
  `NamedTuple` is acceptable when tuple unpacking at the call site is genuinely
  useful.
- **Always use abstract collection types in signatures**: `Sequence` over `list`
  or `tuple`, `Mapping` over `dict`, `Iterable` where only iteration is needed.
  Implementations may use concrete types freely.
- **Never silence type errors**: fix the underlying type issue instead of adding
  `# type: ignore` or `cast()`. If silencing genuinely seems like the right
  call, stop, explain the case to the user, and get explicit approval.
- **Never use `typing.Any`**: prefer `object` for unvalidated external data
  (forces explicit narrowing at use sites), a concrete type if the shape is
  known, or a `TypedDict`/`Protocol` when structure matters. If `Any` genuinely
  seems like the right call despite this rule, stop, explain the case to the
  user, and get explicit approval before proceeding.

## Testing

- **Use comment headers to group related tests**: use `# --- subject ---`
  sections, not classes — classes add nesting with no benefit when grouping is
  the only purpose. Use classes only when shared fixtures or setup genuinely
  require them.

## Exceptions

- **When raising an exception**: use a built-in type only when the error
  genuinely fits its definition — `ValueError` for wrong values, `TypeError` for
  wrong types, `RuntimeError` for unexpected runtime state. When no built-in
  fits, define a purpose-built exception class — every `except` clause is then
  unambiguous about what it handles.
- **When defining a custom exception**: never inherit from a built-in solely to
  piggyback on existing catch clauses — the type hierarchy should reflect what
  each error means.
