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
- **Plain language over jargon**: use real, everyday words instead of acronyms
  or insider jargon — in chat responses, comments, docstrings, and documentation
  alike. Standard technical terms (API, HTTP, JSON, CLI, regex) are fine as-is;
  avoid reaching for an obscure or invented acronym when a plain phrase says the
  same thing as clearly
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
- **Comment and docstring prose is markdown**: a blank comment line separates
  paragraphs; adjacent plain lines are one paragraph and may merge under reflow,
  so express structure as markdown (`-` bullets, backticked code, fenced
  blocks). Auto-reflow exists where a rules/ file documents it (Python:
  `rules/python.md`); elsewhere, fit prose to the limit by hand
- **Named helpers**: extract repeated expressions into named constants or helper
  variables rather than repeating them inline
- **Decompose complex regexes**: when a pattern combines two or more distinct
  components — anchors, character classes, groups, alternation — bind each
  logical part to a named piece so its intent is legible without decoding the
  whole pattern. The mechanism is language-specific (see the per-language
  rules); the goal is constant — a name says what a sub-pattern matches where a
  bare cluster of metacharacters can't
- **Don't name for the sake of naming**: a name earns its existence by being
  referenced in multiple places, or by communicating something the value
  doesn't. A constant used in exactly one place adds a layer of indirection with
  no payoff — inline it
- **Simplicity**: when two approaches are otherwise equivalent, choose the
  simpler one
- **Type annotations**: annotate all definitions where the language supports it
- **Factoring**: extract for clarity; don't abstract ahead of actual reuse
- **Well-scoped names and labels**: name anything that groups content — a
  module, a file, a section — for exactly what it covers: `parsing.py`,
  `formatting.py` — not `util.py`, `helpers.py`, or `common.py`. A focused name
  makes it immediately clear whether new content belongs under it
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
- **License**: include a license block at the top of every source file — most
  repos here are public, so the block removes licensing ambiguity. For personal
  projects, default to MIT: a copyright line followed by an SPDX identifier
  (e.g. `# Copyright YEAR Name` / `# SPDX-License-Identifier: MIT`, using the
  language's comment syntax). Default name: `Ilya Sherman (ishermandom@)`. Never
  add the block to markdown or other prose files — the repo's `LICENSE` covers
  them
- **Abstract types in API signatures**: prefer abstract collection types over
  concrete ones in function signatures — the contract should express
  constraints, not implementation details. Applies to parameters and return
  types alike.

## Persisting preferences and insights {#disprefer-memory}

Prefer a tracked file over the auto-memory store whenever one fits: an
in-project file (`tasks.md`, a spec, a README) for project state, or CLAUDE.md
itself for a preference or insight that's global and authoritative across every
project. Both are git-tracked and reviewable; auto-memory is neither — reserve
it for what doesn't belong in a tracked file: a project-local fact too informal
to track, or one that recalls rarely enough that its load-only-when-recalled
cost pays off.

## Interaction style

When gathering structured preferences or exploring a decision with a small,
enumerable option set, use `AskUserQuestion` with multiple-choice options
proactively — don't wait to be asked. Good triggers: tool/library selection,
design tradeoffs, threat-model exercises, preference gathering before writing a
doc or config.

- **Concision**: Surface what the reader needs to act on or understand; cut the
  rest. Between short and clear, choose clear; at equal clarity, choose short.
- **Concrete example first**: when explaining a bug or behavior — most sharply
  when the user asks "what's the issue", "show me", or "give me an example" —
  lead with the smallest input+output that reproduces it, before any conceptual
  account. Let the example carry the explanation, then add whatever it doesn't
  already make self-evident. A minimal repro is usually clearer than a
  walkthrough.
- **Context before questions**: before asking the user to decide anything that
  rests on context they haven't seen (research findings, file contents,
  tradeoffs), present that context and end the turn; ask the questions in a
  following turn. Same-turn text gets buried behind the question UI.
- **`aq` shorthand**: When the user writes `aq` (alone or with a topic), gather
  the open decisions via `AskUserQuestion`.
- **`nojar` shorthand**: When the user writes `nojar` (with a request, or alone
  after a response), apply the plain-language style rule with extra force to the
  writing in question — spell words out rather than using acronyms, choose
  everyday phrasing over jargon — rewriting the previous response when `nojar`
  stands alone. It dials acronym use down, not to zero — standard technical
  terms stay fine.
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
  I'm now checking Z" signals; "Reading file X" does not. A countable tripwire:
  more than ~3 tool calls since the last user-visible text means a status line
  is overdue — post one now. A long reasoning pass is invisible to the user —
  thinking tokens don't register as tool calls, so an instinct keyed on
  tool-call volume under-signals it. For algorithmic or edge-case-heavy work,
  prefer breaking it up and externalizing verification (a first cut plus tests,
  run) over simulating every case in one internal pass — that is both more
  visible and more efficient. Pace by task structure, not a clock interval.
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

## Working method

- **Technology currency**: For questions about current best-in-class tools,
  models, or libraries, run a web research agent call before making
  recommendations — training data may be a year or more stale. Good triggers:
  "what's the best X", model/library selection, version comparisons.
- **No source is an oracle — reason from consistency, not authority.** Repo
  content (code, comments, specs, docs) was written by an earlier Claude or the
  user; the current request can itself sit at odds with the spec. None is
  automatically right. When an artifact contradicts actual behavior, the spec,
  or plain sense — or a fresh request departs from the spec without being an
  obvious improvement — treat it as a candidate defect to examine, not a
  constraint to satisfy. The same skepticism applies when an artifact's stated
  scope or name accurately describes today's usage yet would foreclose a cleaner
  design: an accurate account of what is carries no claim about what must be. If
  the correct reading is clear, act and state what and why; if it stays
  genuinely unclear, surface the discrepancy rather than silently choosing.
- **Effort–expectation mismatch**: when a task proves disproportionately hard
  relative to what the user seems to expect — repeated dead ends, an
  impossible-looking situation, reasoning ballooning past the apparent size of
  the ask — stop and surface the discrepancy rather than pushing through. The
  likely cause is a broken premise: a typo, a misunderstanding, or a capability
  that doesn't exist — and pushing through tends to end in a confidently wrong
  answer. Realign first, preferring cheap experiments that test the premise.
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

- **When rules conflict, or appear to**: surface it in chat and proceed on the
  more-specific-wins resolution — a rules/ file overrides CLAUDE.md for its
  path. Name the files and the tentative resolution, e.g. "markdown.md says X,
  CLAUDE.md says Y — following markdown.md as more specific." Never resolve a
  conflict silently, however clear the winner.
- **When violating or noticing a rule violation**: Surface it to the user in
  chat — don't silently override a rule, even when the existing codebase
  conflicts with it.
- **After `Write` on a new file**: path-matched rules don't load until a
  matching file is Read. `Read` a short excerpt (line 1 suffices), self-review
  against the loaded rules, and `Edit` if there are gaps.
- **Before reading or editing files in the dotfiles repo**: edits happen at the
  real paths behind the `~/.claude` symlinks — outside the project, where
  path-matched rules never fire. (Exception: in a session whose working project
  is the dotfiles repo itself, skip this — reading a file at its repo path loads
  the matching rules automatically.) First `Read` the matching rules file, then
  check the work against it:
  - `*.py` → `~/.claude/rules/python.md`
  - `*.sh` → `~/.claude/rules/shell.md`
  - `*.md` → `~/.claude/rules/markdown.md` and
    `~/.claude/rules/claude-configuration.md`
  - `settings.json` or files under `hooks/` →
    `~/.claude/rules/claude-configuration.md`, in addition to a hook script's
    language rule
  - any file with `test` in its name → `~/.claude/rules/testing.md`, in addition
    to its language rule

## Review approach

**When a durable chunk of work is complete** — a feature, a refactor, a new file
or skill, anything meant to last — work it end-to-end, then review (before or
after committing, but before any push) rather than gating each increment
mid-construction. The aim is the user's ownership of what lands — maintainable
by the user solo by default, key decisions ratified at minimum. Drive the review
with the `/ownership-walkthrough` skill.

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

**When work is exploratory** — a spike, a feasibility probe, a design sketch —
propose the lighter prototyping bar. Enter exploratory mode only with the user's
confirmation, and default to production when unsure. Prototype code lives under
a `scratch/` directory.

## Plan documents

Treat plan documents as multi-session work queues by default. Complete the
explicitly requested item, then stop. After completing it, suggest a next step
only if carrying it out now is meaningfully more efficient with the current live
context than saving state and starting fresh — e.g., the work is tightly coupled
to what's already in context, or the setup cost in a new session would be
significant. Otherwise, say nothing and let the user drive.

## Token and context efficiency

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
- **After a raw edit that bypasses `Edit`/`Write`** (e.g. a script-driven
  multi-file find/replace): their `PostToolUse` formatting hooks — prose reflow,
  prettier — never fired either. Run the real formatter on the file
  (`~/.claude/scripts/quiet-prettier.sh` for markdown/JS;
  `python3 ~/.claude/hooks/reflow_prose.py <path>` for Python) rather than
  hand-fixing line lengths, which won't quite match what the hook would have
  produced.
- **Prefer to search code with `rg`**: ripgrep for recursive searches. The
  bundled `grep` shim (backed by ugrep) handles quick literal or piped lookups,
  and is the better pick for compressed/archived logs and fuzzy matching — but
  it runs in BRE mode: `|`, `+`, `(` are literal without `-E`.
- **Read files incrementally**: use `grep`/`find` to locate relevant sections,
  then read only those ranges with `offset`/`limit`. For edits, grep for the
  insertion point and read a small window around it — a full file read is rarely
  needed. Read a file in full only when you need to understand interactions
  across distant sections. For multi-file exploration, use the `Explore`
  subagent. Don't read multiple related files in parallel speculatively — start
  with the most likely relevant one and expand only if needed. Log and config
  files are usually analysis inputs — prefer a grep or windowed read of the
  relevant section over a full read.

## Documentation

- **Concepts over implementation**: Explain what something is trying to achieve
  and why, not just what it does. This applies everywhere — docstrings, inline
  comments, and user-facing documentation alike. Implementation details can
  supplement conceptual framing, but never substitute for it.
- **Lead with goals**: Open with what something is trying to achieve.
  Constraints and tradeoffs are secondary.
- **Tone**: Matter-of-fact and gentle, not lawyerly or heavy-handed. Avoid
  language that sounds defensive or thorny.
- **Less is more**: Before explaining something, ask whether the explanation is
  needed. Often the facts speak for themselves.
- **Factual precision**: Verify physical, operational, and real-world details
  against the source. Don't paraphrase when exact behavior matters.
- **Don't write predictably stale content**: When a statement tracks a moving
  target — versions, counts, state recorded elsewhere — point at the source of
  truth or leave it out.

## Git

- **Default**: commit directly to `main`; don't branch first. The user works one
  thread at a time and reviews locally, so the harness branch-first default
  doesn't apply. Branch or use a worktree only for a specific need — an
  abandonable spike, parallel agents, etc.

### Committing

- **Never commit the dotfiles repo without the user's explicit permission** for
  the specific change — a slipped change there can silently degrade every other
  protection.
- **Otherwise, commit freely within the session's working project**: no
  per-commit ask — the permission mode is the gate (a prompt in regular mode,
  granted scope in auto mode).
- **Before committing outside the session's working project** — most commonly,
  dotfiles edits made from another project's session — always ask first,
  regardless of permission mode: commit authorization is scoped to the session's
  project, not to every repo the session touches. A request that explicitly asks
  to commit ("commit the dotfiles change") is that permission — no second ask; a
  request to make a change does not itself grant permission to commit it.
- **Message format**: subject line <= 72 chars; wrap the remaining lines at 80
  columns.
- **Multi-line messages**: always pass through a heredoc
  (`git commit -F - <<'EOF'`), never stacked `-m` flags — the heredoc shows the
  line breaks literally, so the 72/80-col wrapping is verifiable in the command
  itself.
- **Before amending a commit**: amend only when the intermediate state has no
  standalone value (typo fixes, immediate fix-ups); otherwise — and whenever
  uncertain — stack a new commit. Lost history costs more than extra commits.
  Never amend a pushed commit.
- **Never rewrite history on `main`, and keep it fully linear**: no rebases, no
  merge commits, no restructuring. Exception: amending the unpushed tip is fine
  when the amend rule allows it — an amend keeps history linear.
- **Review is a separate axis from committing**: committing never waits on
  review, but all production code must be user-reviewed — before or after the
  commit, and always before it's pushed; `scratch/` code needs no review.

### Working on a branch (typically a worktree)

- **Branch commit quality**: hold every branch commit to main's bar — code
  quality, message standards, `scratch/` for relaxed rigor — because it lands on
  main verbatim.
- **Keep the branch current**: rebase it onto `main` periodically.
- **To correct a not-yet-landed branch commit**: `git commit --fixup <commit>`
  rather than a fresh "fix the previous commit" message — the landing rebase
  runs `--autosquash`, folding each fixup into its target; `--amend` works
  equally well when the correction targets the branch tip.
  - On `main`, never use `--fixup` — nothing ever rebases main to fold it;
    correct the unpushed tip per the amend rule, or stack a plain commit.
- **Rewriting branch history** (fixups, reordering, splitting, squashing): on
  branches other than `main`, rewrite history freely when it clarifies, without
  asking the user first; ask only when the rewrite genuinely needs their input.
- **To sync a branch into `main`**, at any point: run `git land`
  (`~/.claude/scripts/git-land.sh`) — it rebases the branch onto `main` and
  fast-forwards `main`, so main stays linear and every branch commit lands
  individually; landing never squashes. Sync from a stable branch state —
  there's no point landing a broken one.
- **Before `git land`**: production code must be user-reviewed — either as the
  branch evolved or as part of landing; `scratch/`-only changes need no review.
  When unsure whether something was reviewed, err toward suggesting a review —
  and only ever suggest one, never initiate it. Also give the branch history a
  final look — a rewrite may leave main's log clearer.

### GitHub

- **Never push a branch to a remote** — only `main` pushes.
- **When pushing**: always use `origin-https`, never `origin` — the sandbox's
  fine-grained tokens ride HTTPS; it holds no SSH key.
- **After creating a new repo**: run `~/.claude/scripts/gh-protect.sh` to verify
  its branch-protection ruleset; on a reported gap, ask the user to create the
  printed ruleset in the GitHub UI.
