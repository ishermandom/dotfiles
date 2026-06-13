# Global style guide

## Foundational principle: low cognitive load

Every style decision flows from one goal: minimize the mental effort required to
read and understand code. In practice this means:

- A reader should grasp any section without scrolling
- Names should communicate their purpose at a glance
- Visual structure should mirror logical structure
- Complexity that doesn't earn its keep should be removed

## Project context

Projects here are personal hobby projects, typically long-lived. Rigor and
consistency are goals in themselves — these projects keep professional skills
fresh. Never lower the quality bar because a project is small.

## Style

- **Line length**: 80 columns; wrap at 80 unless wrapping is clearly more
  awkward than a longer line
- **Blank lines**: use them to create visual breathing room between logical
  sections — structure on the page should reflect structure in the logic
- **Logical operators in multi-line expressions**: place `and`/`or` at the start
  of the continuation line, not at the end of the preceding one — this groups
  the operator visually with the operand it introduces and aligns parallel
  conditions at the same indent
- **Naming**: names answer "X what?" — neither terse nor verbose. `page_count`
  not `count`; not `the_total_number_of_pages`
- **No abbreviations in names**: spell words out in full. Manage length by
  choosing precise, tight terminology — not by truncating words.
  `solvability_parser` not `solv_parser`; `message` not `msg`. Exception:
  established language-level conventions such as `args`, `*args`, `**kwargs`,
  and loop variables (`i`, `e`) where the abbreviated form is the canonical name
- **Boolean names**: prefix with `is_`, `has_`, `can_`, `does_`, or another verb
  that communicates boolean intent at a glance — `satisfies_foo`, `uses_foo`,
  `allows_foo`. A bare noun like `tense_agreement` doesn't signal its type;
  `has_tense_agreement` does
- **Docstrings**: brief docstring on every top-level definition, even simple
  ones. "Brief" means efficiently articulated, not just short. Use structured
  sections (Args, Returns, etc.) only when they genuinely add clarity over prose
- **Inline comments**: at the specific line(s) that do the work, not only in the
  docstring. The reader should not have to scroll to understand what a branch
  does
- **Comments describe what is, not what was**: history belongs in git — commit
  messages, PR descriptions, blame. A comment explaining what changed, what used
  to be, or why something is no longer the case crowds out the current truth and
  ages into misinformation
- **TODOs**: write known tradeoffs as TODO comments when not addressing them
  now, so they aren't lost as mental notes. Always place a TODO on its own line
  — never append it to a line that carries other content
- **Named helpers**: extract repeated expressions into named constants or helper
  variables rather than repeating them inline
- **Don't name for the sake of naming**: a name earns its existence by being
  referenced in multiple places, or by communicating something the value
  doesn't. A constant used in exactly one place adds a layer of indirection with
  no payoff — inline it
- **Simplicity**: when two approaches are otherwise equivalent, choose the
  simpler one
- **Type annotations**: annotate all definitions where the language supports it
- **Factoring**: extract for clarity; don't abstract ahead of actual reuse
- **Name shared modules by what they do**: `parsing.py`, `formatting.py` — not
  `util.py`, `helpers.py`, or `common.py`. A focused name makes it immediately
  clear whether a new helper belongs in that file
- **Use enums for bounded value sets**: when a variable or parameter accepts one
  of a known, finite set of values, define an enum rather than passing raw
  literals. This documents what's valid, enables IDE support, and catches
  invalid values at the call site
- **Don't fail silently**: when a function encounters unexpected state, make the
  failure visible — raise an exception, log an error, or surface it to the
  caller. Returning a sentinel value can be the right contract when the caller
  is expected to handle it, but using one to paper over an error that shouldn't
  occur hides bugs
- **Narrow exception handling**: a `try` block should wrap only the specific
  statement(s) that can raise; `except` should name only the exact types those
  statements produce. A wide try that covers several statements hides which
  operation actually failed and can accidentally catch exceptions it was never
  meant to handle
- **Include context in error messages**: an error message should contain enough
  information to diagnose the problem without reproducing it. Include relevant
  inputs — or an excerpt, if they can be large
- **Prefer instance state over module-level globals**: a module-level object is
  implicit shared state that can't be overridden in tests without reaching into
  the module internals. A class that accepts its dependencies through the
  constructor makes them explicit and replaceable
- **License**: include a license block at the top of every source file. For
  personal projects, default to MIT: a copyright line followed by an SPDX
  identifier (e.g. `# Copyright YEAR Name` / `# SPDX-License-Identifier: MIT`,
  using the language's comment syntax). Default name:
  `Ilya Sherman (ishermandom@)`
- **Abstract types in API signatures**: prefer abstract collection types over
  concrete ones in function signatures — the contract should express
  constraints, not implementation details. Applies to parameters and return
  types alike.

## Configuration

- **Global by default**: put hooks, settings, and scripts in `~/.claude/` unless
  the behavior is genuinely project-specific. Project-scoped config
  (`.claude/settings.json`, `.claude/hooks/`) is for things tied to one repo — a
  project-specific toolchain, permissions, or environment variable. When in
  doubt, ask: would this rule apply in a different project? If yes, it's global.

## Hooks

- **Scope check first**: before wiring a new hook, apply the global-by-default
  rule above — hooks go in `~/.claude/settings.json` and `~/.claude/hooks/`
  unless there's a concrete project-specific reason.
- Inlined hook commands should be trivial to understand at a glance. Any
  nontrivial logic belongs in an external shell script at
  `.claude/hooks/<name>.sh`. Scripts are readable, auditable, and verifiable
  without running them.
- **Test hooks run on Stop**: a single turn often has multiple interdependent
  edits; running tests after each edit produces false failures mid-turn. Wire
  test hooks to `Stop` so they run once, after all edits have landed.
- **Validate after adding**: after wiring up a new hook, trigger the expected
  behavior and confirm the hook fires correctly — e.g. introduce a deliberate
  failure to verify a test hook catches it, then restore.

## Interaction style

When gathering structured preferences or exploring a decision with a small,
enumerable option set, use `AskUserQuestion` with multiple-choice options
proactively — don't wait to be asked. Good triggers: tool/library selection,
design tradeoffs, threat-model exercises, preference gathering before writing a
doc or config.

- **Concision**: Surface what the reader needs to act on or understand; cut the
  rest. Between short and clear, choose clear; at equal clarity, choose short.
- **Context before questions**: before asking the user to decide anything that
  rests on context they haven't seen (research findings, file contents,
  tradeoffs), present that context and end the turn; ask the questions in a
  following turn. Same-turn text gets buried behind the question UI.
- **Technology currency**: For questions about current best-in-class tools,
  models, or libraries, run a web research agent call before making
  recommendations — training data may be a year or more stale. Good triggers:
  "what's the best X", model/library selection, version comparisons.
- **`aq` shorthand**: When the user writes `aq` (alone or with a topic), gather
  the open decisions via `AskUserQuestion`.
- **Inline upskilling notes**: when a Claude Code feature, tool, or pattern
  would have helped the task at hand, say so at the moment it's relevant. Inline
  is the default delivery; the wrap-session step catches patterns not visible
  mid-conversation.
- **Disagreement and pushback**: never silently execute an approach believed to
  be mistaken — going along is worse than the friction of raising it. Raise
  concerns at planning time — before code is written — calibrated by
  consequence:
  - A preference or minor inefficiency, easily changed later: note it in one
    sentence and proceed.
  - Likely rework, wrong results, or a hard-to-reverse choice: stop and ask
    before executing.
  - Confident the approach breaks something or contradicts the stated goal:
    don't execute; explain and propose an alternative.
- **Effort–expectation mismatch**: when a task proves disproportionately hard
  relative to what the user seems to expect — dead ends repeat, the situation
  looks impossible, reasoning balloons past the apparent size of the ask — stop
  and surface the discrepancy rather than pushing through. The likely cause is a
  broken premise: a typo, a misunderstanding, or a capability that doesn't
  exist. Pushing through tends to end in a confidently wrong answer. Realign
  first, and prefer cheap experiments that test the premise.
- **After two failed attempts at the same issue**: stop and diagnose the root
  cause before trying a third — don't rerun unchanged commands or iterate patch
  variations on weak understanding; that retry loop converges on a fix that
  silences the symptom while the bug survives. Once the root cause is
  understood, present the fix and name explicitly whether it addresses the root
  cause or only a symptom — the user chooses whether a symptom fix is
  acceptable.

## Following rules

- **When rules conflict**: Follow the more specific context — a rules/ file
  overrides CLAUDE.md for that path.
- **When rules appear to conflict**: Surface it in chat before proceeding. Name
  the files, state the conflict, and state Claude's tentative resolution, e.g.
  "markdown.md says X, CLAUDE.md says Y — following markdown.md as more
  specific." Expose ambiguity for clarification rather than silently guessing.
- **When violating or noticing a rule violation**: Surface it to the user in
  chat — don't silently override a rule, even when the existing codebase
  conflicts with it.
- **After `Write` on a new file**: path-matched rules don't load until a
  matching file is Read. `Read` a short excerpt (line 1 suffices), self-review
  against the loaded rules, and `Edit` if there are gaps.
- **Before reading or editing files in the dotfiles repo**: edits happen at the
  real paths behind the `~/.claude` symlinks — outside the project, where
  path-matched rules never fire. First `Read` the matching rules file, then
  check the work against it:
  - `*.sh` → `~/.claude/rules/shell.md`
  - `*.md` → `~/.claude/rules/markdown.md` and
    `~/.claude/rules/claude-rules-style.md`

## Review approach

Work in small, focused increments — each one reads like a pull request with a
single clear purpose (add a skeleton, implement one specific piece of
functionality, add error handling for one case, etc.).

For each increment:

- Lead with a brief description: what this chunk adds, and what's explicitly
  deferred to the next
- Explain key decisions and tradeoffs before presenting code
- Wait for approval before moving to the next increment

For bug fixes and refactors where the change is inherently a single unit, apply
the same spirit — focused scope, described upfront — without forcing an
artificial split.

Before presenting any code, check it against all loaded style guides —
explicitly, as a checklist pass, not by passive recall. This applies to every
edit, however small; the rules most likely to slip through are those unrelated
to the change's main focus.

When the user gives multiple tasks at once, add them all to the project's
`tasks.md` (the task tracker) first and ask which to start with. Don't act on a
list of items in sequence without checking in between.

## Plan documents

Treat plan documents as multi-session work queues by default. Complete the
explicitly requested item, then stop. After completing it, suggest a next step
only if carrying it out now is meaningfully more efficient with the current live
context than saving state and starting fresh — e.g., the work is tightly coupled
to what's already in context, or the setup cost in a new session would be
significant. Otherwise, say nothing and let the user drive.

## Token and context efficiency

### Standing rules

Every session, without being asked:

- **Never re-read `CLAUDE.md`** — it's injected automatically into every
  message.
- **Don't `Read` without justification** — before calling `Read`, explicitly
  state why the current context is insufficient. If the file appeared in any
  prior tool result this session, use that; don't fetch again.
- **Prefer `Edit` over `Write` for existing files** — `Edit` sends only the
  diff; `Write` re-sends the whole file. Before doing a full `Write` on an
  existing file, flag it and confirm.
- **Resolve symlinks before editing** — `Edit` and `Write` reject symlink paths,
  wasting a round-trip. Use `readlink -f <path>` to get the real path first.
  Many files under `~/.claude` (including `CLAUDE.md` itself) are symlinks into
  a dotfiles repo — always dereference before editing any path in that
  directory.
- **Before running pytest, mypy, ruff, or prettier**: they run automatically at
  Stop — never invoke the bare tools yourself (a PreToolUse gate denies them).
  Run a check mid-turn only when its result changes what happens this turn (e.g.
  confirming an intermediate state lets more work land now), and then via the
  wrappers `~/.claude/scripts/quiet-{tests,mypy,ruff,prettier}.sh [paths]` —
  terse output, auto-surfaced to the user.
- **Prefer parallel tool calls** when independent.
- **Read files incrementally**: use `grep`/`find` to locate relevant sections,
  then read only those ranges with `offset`/`limit`. For edits, grep for the
  insertion point and read a small window around it — a full file read is rarely
  needed. Read a file in full only when you need to understand interactions
  across distant sections. For multi-file exploration, use the `Explore`
  subagent. Don't read multiple related files in parallel speculatively — start
  with the most likely relevant one and expand only if needed.

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

## Documentation

- **Concepts over implementation**: Explain what something is trying to achieve
  and why, not just what it does. This applies everywhere — docstrings, inline
  comments, and user-facing documentation alike. Implementation details can
  supplement conceptual framing, but never substitute for it.
- **Lead with goals**: Open with what something is trying to achieve.
  Constraints and tradeoffs are secondary.
- **Section labels match their content precisely**: A label broader than its
  section misleads. Narrow the label before broadening the section.
- **Tone**: Matter-of-fact and gentle, not lawyerly or heavy-handed. Avoid
  language that sounds defensive or thorny.
- **Less is more**: Before explaining something, ask whether the explanation is
  needed. Often the facts speak for themselves.
- **Factual precision**: Verify physical, operational, and real-world details
  against the source. Don't paraphrase when exact behavior matters.
- **Don't write predictably stale content**: When a statement tracks a moving
  target — versions, counts, state recorded elsewhere — point at the source of
  truth or leave it out.

# Git

- When pushing to GitHub, always use `origin-https`, not `origin`.
- After creating a new GitHub repo, run `~/.claude/scripts/gh-protect.sh` to
  verify its branch-protection ruleset; on a reported gap, ask the user to
  create the printed ruleset in the GitHub UI.
- When already in the correct working directory, run `git` commands directly
  without the `-C <path>` flag.
- For commit descriptions: keep the subject line to <= 72 chars, and wrap to
  80-col for the remaining lines.
- Before amending a commit: amend only when the intermediate state has no
  standalone value (typo fixes, immediate fix-ups); otherwise — and whenever
  uncertain — stack a new commit. Lost history costs more than extra commits.
  Never amend pushed commits.
- Before committing in any repo other than the current working project — most
  commonly, dotfiles edits made from another project's session — always ask
  first, regardless of permission mode: commit authorization is scoped to the
  session's project, not to every repo the session touches.
