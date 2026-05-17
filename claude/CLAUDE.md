# Global style guide

## Foundational principle: low cognitive load

Every style decision flows from one goal: minimize the mental effort required to read and understand code. In practice this means:

- A reader should grasp any section without scrolling
- Names should communicate their purpose at a glance
- Visual structure should mirror logical structure
- Complexity that doesn't earn its keep should be removed

## Style

- **Line length**: 80 columns; wrap at 80 unless wrapping is clearly more awkward than a longer line
- **Blank lines**: use them to create visual breathing room between logical sections — structure on the page should reflect structure in the logic
- **Naming**: names answer "X what?" — neither terse nor verbose. `page_count` not `count`; not `the_total_number_of_pages`
- **Docstrings**: brief docstring on every top-level definition, even simple ones. "Brief" means efficiently articulated, not just short. Use structured sections (Args, Returns, etc.) only when they genuinely add clarity over prose
- **Inline comments**: at the specific line(s) that do the work, not only in the docstring. The reader should not have to scroll to understand what a branch does
- **Comments describe what is, not what was**: history belongs in git — commit messages, PR descriptions, blame. A comment explaining what changed, what used to be, or why something is no longer the case crowds out the current truth and ages into misinformation
- **TODOs**: write known tradeoffs as TODO comments when not addressing them now, so they aren't lost as mental notes
- **Named helpers**: extract repeated expressions into named constants or helper variables rather than repeating them inline
- **Don't name for the sake of naming**: a name earns its existence by being referenced in multiple places, or by communicating something the value doesn't. A constant used in exactly one place adds a layer of indirection with no payoff — inline it
- **Simplicity**: when two approaches are otherwise equivalent, choose the simpler one
- **Type annotations**: annotate all definitions where the language supports it
- **Factoring**: extract for clarity; don't abstract ahead of actual reuse
- **Use enums for bounded value sets**: when a variable or parameter accepts one of a known, finite set of values, define an enum rather than passing raw literals. This documents what's valid, enables IDE support, and catches invalid values at the call site
- **Don't fail silently**: when a function encounters unexpected state, make the failure visible — raise an exception, log an error, or surface it to the caller. Returning a sentinel value can be the right contract when the caller is expected to handle it, but using one to paper over an error that shouldn't occur hides bugs
- **Include context in error messages**: an error message should contain enough information to diagnose the problem without reproducing it. Include relevant inputs — or an excerpt, if they can be large
- **Prefer instance state over module-level globals**: a module-level object is implicit shared state that can't be overridden in tests without reaching into the module internals. A class that accepts its dependencies through the constructor makes them explicit and replaceable
- **License**: include a license block at the top of every source file. For personal projects, default to MIT: a copyright line followed by an SPDX identifier (e.g. `# Copyright YEAR Name` / `# SPDX-License-Identifier: MIT`, using the language's comment syntax). Default name: `Ilya Sherman (ishermandom@)`
- **Abstract types in API signatures**: prefer abstract collection types over concrete ones in function signatures — the contract should express constraints, not implementation details. Applies to parameters and return types alike.

## Python

- 2-space indentation; single quotes
- Anchor to the Google Python Style Guide, overriding where personal preferences conflict
- Enforcement: ruff + mypy (configured globally in `~/.config/ruff/pyproject.toml` and `~/.claude/settings.json`)
- **Idiomatic truth-value testing**: prefer Python's built-in conventions over explicit type checks. Use `if not foo:` rather than `if foo is None:` to check for absent content — the idiomatic form is shorter and often stricter
- **Named return types**: prefer `@dataclass(frozen=True)` over bare tuples when returning multiple values from a function. Frozen dataclasses are immutable, named, and don't expose confusing positional access. `NamedTuple` is acceptable when tuple unpacking at the call site is genuinely useful.
- **Abstract collection types in signatures**: use `Sequence` over `list` or `tuple`, `Mapping` over `dict`, `Iterable` where only iteration is needed — in signatures. Implementations may use concrete types freely.
- **Exception type semantics**: an exception's type is part of its contract — it tells callers what category of failure occurred. Use built-in types only when the error genuinely fits their definition: `ValueError` means a value of the right type but an inappropriate magnitude or content; `TypeError` means the wrong type; `RuntimeError` is a generic catch-all for unexpected runtime state. When no built-in fits, define a purpose-built exception class — the cost is one small class, and the payoff is that every `except` clause is unambiguous about what it's handling. Don't inherit from a built-in solely to piggyback on existing catch clauses; that makes the type hierarchy misleading.

## Interaction style

When gathering structured preferences or exploring a decision with a small,
enumerable option set, use `AskUserQuestion` with multiple-choice options
proactively — don't wait to be asked. Good triggers: tool/library selection,
design tradeoffs, threat-model exercises, preference gathering before writing
a doc or config.

- **Technology currency**: For questions about current best-in-class tools,
  models, or libraries, run a web research agent call before making
  recommendations — training data may be a year or more stale. Good
  triggers: "what's the best X", model/library selection, version
  comparisons.

## Review approach

Work in small, focused increments — each one reads like a pull request with a single clear purpose (add a skeleton, implement one specific piece of functionality, add error handling for one case, etc.).

For each increment:

- Lead with a brief description: what this chunk adds, and what's explicitly deferred to the next
- Explain key decisions and tradeoffs before presenting code
- Wait for approval before moving to the next increment

For bug fixes and refactors where the change is inherently a single unit, apply the same spirit — focused scope, described upfront — without forcing an artificial split.

Before presenting any code, check it against the style rules in this guide.

## Plan documents

Treat plan documents as multi-session work queues by default. Complete the explicitly requested item, then stop. After completing it, suggest a next step only if carrying it out now is meaningfully more efficient with the current live context than saving state and starting fresh — e.g., the work is tightly coupled to what's already in context, or the setup cost in a new session would be significant. Otherwise, say nothing and let the user drive.

## Token and context efficiency

### Standing rules

Every session, without being asked:

- **Never re-read `CLAUDE.md`** — it's injected automatically into every message.
- **Check context before `Read`** — if the file is already in a prior tool result
  or the system prompt, use it; don't fetch again.
- **Prefer `Edit` over `Write` for existing files** — `Edit` sends only the diff;
  `Write` re-sends the whole file. Before doing a full `Write` on an existing
  file, flag it and confirm.
- **Resolve symlinks before editing** — `Edit` and `Write` reject symlink paths,
  wasting a round-trip. Use `readlink -f <path>` to get the real path first.
  Many files under `~/.claude` (including `CLAUDE.md` itself) are symlinks into
  a dotfiles repo — always dereference before editing any path in that directory.
- **Prefer parallel tool calls** when independent.
- **Trust hook automation**: don't manually run linting, type-checking, or other checks that hooks are configured to run automatically on save or tool use.
- **Before test work**, read `~/.claude/docs/testing-guide.md`.

### Session-switch guidance

When the session has accumulated context and the user's new request **doesn't
depend on it** (self-contained; could be fully briefed in one sentence without
prior history), say in one sentence: **"This looks self-contained — consider
starting a fresh session."**

When the request **does depend on current context**, say: **"This needs the
current context — staying in this session makes sense."**

### Effort level

When a task arrives, assess complexity and flag in one sentence if the effort
level seems mismatched. Sonnet 4.6 defaults to `high`; `medium` is recommended
for most workloads. Only flag when the mismatch is clear — not on every task.

### On-demand token audit

When asked, read `~/.claude/docs/token-audit.md` for instructions. Don't run unprompted.

## Documentation

- **Concepts over implementation**: Explain what something is trying to achieve and why, not just what it does. This applies everywhere — docstrings, inline comments, and user-facing documentation alike. Implementation details can supplement conceptual framing, but never substitute for it.
- **Lead with goals**: Open with what something is trying to achieve. Constraints and tradeoffs are secondary.
- **Section labels match their content precisely**: A label broader than its section misleads. Narrow the label before broadening the section.
- **Tone**: Matter-of-fact and gentle, not lawyerly or heavy-handed. Avoid language that sounds defensive or thorny.
- **Less is more**: Before explaining something, ask whether the explanation is needed. Often the facts speak for themselves.
- **Factual precision**: Verify physical, operational, and real-world details against the source. Don't paraphrase when exact behavior matters.

# Git

- When pushing to GitHub, always use `origin-https`, not `origin`.
- When already in the correct working directory, run `git` commands directly without the `-C <path>` flag.
- For commit descriptions: keep the subject line to <= 72 chars, and wrap to 80-col for the remaining lines.
