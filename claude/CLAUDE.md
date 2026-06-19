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
- **Keep `settings.json` lists alphabetized**: when adding or editing entries in
  a curated string list (`permissions.allow`, `permissions.deny`), keep the list
  in ASCII sort order. Leave the `hooks` arrays as-is — their order is
  execution-significant, not alphabetical.
  <!-- Lives here, not in settings.json: JSON can't hold a comment. -->

## Hooks

- **Scope check first**: before wiring a new hook, apply the global-by-default
  rule above — hooks go in `~/.claude/settings.json` and `~/.claude/hooks/`
  unless there's a concrete project-specific reason.
- Inlined hook commands should be trivial to understand at a glance. Any
  nontrivial logic belongs in an external script at `.claude/hooks/<name>` —
  shell or Python, whichever fits the logic; prefer Python once it outgrows
  string-mangling. External scripts are readable, auditable, and testable
  without running the hook.
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
- **Inference vs. established fact**: never state an unverified claim with the
  confidence of a verified one. When asserting something not directly checked —
  implementation history, code structure, why a command behaved a certain way —
  flag it as inference ("looks like", "presumably") or verify it against the
  source (git log, the file, the user) first.
- **Visibility during a long stretch**: before going heads-down for a long
  stretch — many tool calls, _or_ extended internal reasoning, design, or
  authoring — post a one-line "here's what I'm about to do," then surface
  findings-oriented status at each checkpoint: a hypothesis confirmed or ruled
  out, a sub-area finished, a direction change. "Found X, which points to Y, so
  I'm now checking Z" signals; "Reading file X" does not. A long reasoning pass
  is invisible to the user — thinking tokens don't register as tool calls, so an
  instinct keyed on tool-call volume under-signals it. For algorithmic or
  edge-case-heavy work, prefer breaking it up and externalizing verification (a
  first cut plus tests, run) over simulating every case in one internal pass —
  that is both more visible and more efficient. Pace by task structure, not a
  clock interval.
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
- **Before spending a live or empirical check on a claim**: confirm the claim is
  load-bearing for a path being recommended or still plausibly in contention.
  Defer checking claims that only support a backup path already being argued
  against — validating an option being steered away from is wasted effort.
  Sequence the decision before validating its sub-mechanics.

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
  - `*.py` → `~/.claude/rules/python.md`
  - `*.sh` → `~/.claude/rules/shell.md`
  - `*.md` → `~/.claude/rules/markdown.md` and
    `~/.claude/rules/claude-rules-style.md`

## Review approach

**When a durable chunk of work is complete** — a feature, a refactor, a new file
or skill, anything meant to last — work it end-to-end, then review before
committing rather than gating each increment mid-construction. The aim is the
user's ownership of what lands — maintainable by the user solo by default, key
decisions ratified at minimum. Drive the review with the
`/ownership-walkthrough` skill.

Before presenting any code, check it against all loaded style guides —
explicitly, as a checklist pass, not by passive recall. This applies to every
edit, however small; the rules most likely to slip through are those unrelated
to the change's main focus. Cover altitude in the same pass, not only style:
confirm the change sits at the right depth and semantics, not just that it
matches the guides.

When choosing how to run that review: for a small diff that fits in full
context, reviewing inline can beat fanning out cold `/code-review` subagents —
but inline review leans on passive recall, so cover every angle deliberately,
conventions and altitude most of all, since those are what otherwise slip past.

When the user gives multiple tasks at once, add them all to the project's
`tasks.md` (the task tracker) first and ask which to start with. Don't act on a
list of items in sequence without checking in between.

## Exploratory mode

**When work is exploratory** — a spike, a feasibility probe, sketching a design
— hold it to a lighter quality bar than production, with the user's confirmation
before entering. Claude may propose the mode when work looks clearly
exploratory; default to production when unsure. Exploratory code lives under a
`scratch/` directory — the durable, visible marker of its intended bar. It may
be committed or not; living in `scratch/` keeps it delineated either way.

While exploring, relax three things:

- **Style** — favor DAMP (repeat-for-clarity) over DRY, and skip factoring
  polish. Clarity-in-the-moment beats durable structure at this bar.
- **Review** — no ownership walkthrough; committing within `scratch/` needs no
  review, since the path already signals the bar.
- **Tests** — by default, write none and keep none green; probe correctness by
  hand.

**When exploratory work graduates to production** — a cue like "let's build this
properly," or moving a file out of `scratch/` — raise it to the production bar
through the ownership review, as a clean reimplementation or a structured
walkthrough. That is the natural reassessment point.

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
- **Don't spend a tool call re-verifying state already guaranteed** — when a
  standing instruction fixes a value (e.g. push to `origin-https`) or a wrong
  value would fail loudly on the next step, skip the confirming query; it costs
  a call, often a permission prompt, for no new information.
- **Prefer `Edit` over `Write` for an existing file** — output tokens drive
  cost, and `Edit` regenerates only the changed lines while `Write` regenerates
  the whole file. `Edit` is cheaper for focused changes; `Write` for a
  near-total rewrite or a large deletion. Pick whichever generates less.
  <!-- Cost driver: output-token generation at call time. Taking input as the 1x
  baseline, per-token rates are uniform across Claude models: output 5x, cache
  write 1.25x, cache read 0.1x. The generated call later sits in context at
  cache-read rates, equal for both, so the comparison reduces to output
  generated — Edit ≈ Σ(old+new strings), Write ≈ final file. Crossover: Write
  wins once touched text approaches the whole file (deleting most of a large
  file, the edits' old_strings sum to more than Write's smaller result). Per-op
  gap is small (a ~500-line file is a few thousand output tokens vs. ~100 for a
  small edit — at most ~$0.30 even on Fable, the priciest model at $50/MTok
  output, as of June 2026) — a soft default, not worth a confirmation
  round-trip. -->

- **Resolve symlinks before editing** — `Edit` and `Write` reject symlink paths,
  wasting a round-trip. Use `readlink -f <path>` to get the real path first.
  Many files under `~/.claude` (including `CLAUDE.md` itself) are symlinks into
  a dotfiles repo — always dereference before editing any path in that
  directory. Read at the resolved path too: a pre-edit `Read` via the symlink
  path doesn't satisfy `Edit`/`Write`'s real-path tracking, so it gets redone.
- **Before running pytest, mypy, ruff, or prettier**: they run automatically at
  Stop — never invoke the bare tools yourself (a PreToolUse gate denies them).
  Run a check mid-turn only when its result changes what happens this turn (e.g.
  confirming an intermediate state lets more work land now), and then via the
  wrappers `~/.claude/scripts/quiet-{tests,mypy,ruff,prettier}.sh [paths]` —
  terse output, auto-surfaced to the user.
- **Prefer parallel tool calls** when independent.
- **Prefer to search code with `rg`**: ripgrep for recursive searches. The
  bundled `grep` shim (backed by ugrep) handles quick literal or piped lookups,
  and is the better pick for compressed/archived logs and fuzzy matching.
  <!-- The `grep` shim runs ugrep in BRE mode (`-G`): `|`, `+`, `(` are
  literal without `-E` — an easy silent misfire. rg defaults to recursive,
  smart-case, gitignore-aware search with an ERE-ish flavor matching how
  patterns get written. -->
- **Read files incrementally**: use `grep`/`find` to locate relevant sections,
  then read only those ranges with `offset`/`limit`. For edits, grep for the
  insertion point and read a small window around it — a full file read is rarely
  needed. Read a file in full only when you need to understand interactions
  across distant sections. For multi-file exploration, use the `Explore`
  subagent. Don't read multiple related files in parallel speculatively — start
  with the most likely relevant one and expand only if needed. Log and config
  files are usually analysis inputs — prefer a grep or windowed read of the
  relevant section over a full read.

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
- For commit descriptions: keep the subject line to <= 72 chars, and wrap to
  80-col for the remaining lines.
- For a multi-line commit message, pass it through a heredoc
  (`git commit -F - <<'EOF'`) rather than stacked `-m` flags — the heredoc shows
  the line breaks literally, so the 72/80-col wrapping is verifiable in the
  command itself.
- Before amending a commit: amend only when the intermediate state has no
  standalone value (typo fixes, immediate fix-ups); otherwise — and whenever
  uncertain — stack a new commit. Lost history costs more than extra commits.
  Never amend pushed commits.
- Before committing in any repo other than the current working project — most
  commonly, dotfiles edits made from another project's session — always ask
  first, regardless of permission mode: commit authorization is scoped to the
  session's project, not to every repo the session touches.
