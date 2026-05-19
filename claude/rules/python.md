---
paths:
  - "**/*.py"
---

# Python style guide

- 2-space indentation; single quotes
- Anchor to the Google Python Style Guide, overriding where personal preferences conflict
- Enforcement: ruff + mypy (configured globally in `~/.config/ruff/pyproject.toml` and `~/.claude/settings.json`)
- **Idiomatic truth-value testing**: prefer Python's built-in conventions over explicit type checks. Use `if not foo:` rather than `if foo is None:` to check for absent content — the idiomatic form is shorter and often stricter
- **Named return types**: prefer `@dataclass(frozen=True)` over bare tuples when returning multiple values from a function. Frozen dataclasses are immutable, named, and don't expose confusing positional access. `NamedTuple` is acceptable when tuple unpacking at the call site is genuinely useful.
- **Abstract collection types in signatures**: use `Sequence` over `list` or `tuple`, `Mapping` over `dict`, `Iterable` where only iteration is needed — in signatures. Implementations may use concrete types freely.
- **No `Any`**: never use `typing.Any`. Prefer `object` for unvalidated external data (forces explicit narrowing at use sites), a concrete type if the shape is known, or a `TypedDict`/`Protocol` when structure matters. If `Any` genuinely seems like the right call despite this rule, stop, explain the case to the user, and get explicit approval before proceeding.

## Testing

- **Test grouping**: use comment section headers (`# --- subject ---`) to group related tests, not classes. Classes add nesting with no benefit when grouping is the only purpose. Use classes only when shared fixtures or setup genuinely require them.

## Exceptions

- **Exception type semantics**: an exception's type is part of its contract — it tells callers what category of failure occurred. Use built-in types only when the error genuinely fits their definition: `ValueError` means a value of the right type but an inappropriate magnitude or content; `TypeError` means the wrong type; `RuntimeError` is a generic catch-all for unexpected runtime state. When no built-in fits, define a purpose-built exception class — the cost is one small class, and the payoff is that every `except` clause is unambiguous about what it's handling. Don't inherit from a built-in solely to piggyback on existing catch clauses; that makes the type hierarchy misleading.
