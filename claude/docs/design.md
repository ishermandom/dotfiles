# Collaboration system design record

This document records the design of a personal Claude Code collaboration system:
the requirements it must meet, the architecture that meets them, and the
rationale behind each decision. The operative configuration lives alongside it
under `~/.claude/`; this record holds the _why_ and references the config as the
source of truth, never mirroring its text.

Organized by topic: Foundations, Architecture, the Working agreement (how a
session is run), and Subsystems (the built mechanisms with their design
rationale). Rationale scoped to a single skill lives in that skill's companion
`notes.md`, not here.

---

## Foundations

### Code ownership

- Every line of production code must be readable, understandable, and
  maintainable by the user solo, without AI assistance. Hard requirement.
- Every line must be understandable on inspection — dense or over-abstracted
  code is not acceptable regardless of correctness.

### Honesty and confidence calibration

- Confident mistakes are the primary failure mode to avoid.
- Uncertainty must be surfaced explicitly; guesses must not be presented as
  facts.
- "This seems infeasible" and "I'm stuck — I need collaboration" are first-class
  acceptable outcomes, not last resorts. Producing a plausible-looking result to
  meet a perceived expectation is always worse than surfacing the problem.

### Use-case profile

- Typical work: small personal hobby projects, driven through interactive
  sessions. Solo — consistency and clarity come from personal style guides, not
  team norms.
- Mostly long-lived: a handful of projects revisited over months or years. Drift
  compounds; cross-session continuity and consistency matter more than raw
  speed.
- Polyglot: Python, shell, and TypeScript/JS today; a Rust project is likely
  soon. Conventions vary by language; assumptions from one language don't always
  translate into another.
- Risk surface: code runs locally — the blast radius of a bug is the user's own
  time and machine. Best practices still apply: keeping professional engineering
  skills fresh is a primary purpose of these projects, so production-grade rigor
  is a goal in itself, not just risk management.

---

## Architecture

The collaboration system has five layers:

| Layer               | Mechanism             | Role                                          |
| ------------------- | --------------------- | --------------------------------------------- |
| Enforcement         | Hooks (settings.json) | Deterministic; runs regardless of context     |
| Always-on rules     | CLAUDE.md             | Short, high-signal; every rule carries weight |
| Reference material  | ~/.claude/docs/       | Topic-clustered; loaded by Claude on-demand   |
| Explicit workflows  | ~/.claude/skills/     | User-triggered slash commands                 |
| Cross-session facts | memory/               | Evolving observations; never standing rules   |

### File layout

The directories below are the source of truth; this sketch shows their roles,
not a full file listing.

```
~/.claude/
  CLAUDE.md                  # Critical rules + always-on style
  settings.json              # Hooks + dangerous-operation blocklist
  rules/                     # Path-scoped style, loaded on a matching file
                             #   (markdown.md, python.md, shell.md, …)
  docs/                      # On-demand reference (this design record lives here)
  hooks/                     # Hook scripts (e.g. format-markdown-on-edit.sh)
  skills/                    # User-triggered workflows
                             #   (distill, ownership-walkthrough, spec,
                             #    wrap-session)
  projects/<project>/
    CLAUDE.md                # Project-specific rules and conventions
    memory/                  # Cross-session facts only
```

### CLAUDE.md and size discipline

CLAUDE.md stays focused and holds only:

- **Core principles** from the style guide (e.g. "minimize cognitive load").
  Detailed rules (line length, naming, language conventions) live in
  `~/.claude/rules/` as path-scoped rule files and load mechanically when Claude
  opens a matching file — not advisory. Not all sessions produce code; path
  scoping ensures style rules only appear in context when relevant.
- **Critical rules** that hooks cannot enforce: no auto-commit, prototype
  separation, scope discipline, plan format requirements.
- **Maintainer notes**: HTML block comments (`<!-- ... -->`) are stripped before
  injection from CLAUDE.md (auto-loaded) and from rules files (injected by
  path-matching) — zero token cost, so they document a rule's rationale without
  spending context budget. Stripping is a property of the injection path, not
  the file type: docs and `SKILL.md` enter context verbatim (read on demand, or
  injected when the skill runs), so comments there cost tokens. Verified
  empirically 2026-06-13: a sentinel comment in a rules file was stripped from
  its path-matched injection, while one in a throwaway doc survived a `Read`.
  The operative convention lives in `rules/claude-rules-style.md` (Maintainer
  rationale); skill rationale belongs in a companion notes file.

Why the size cap: always-loaded guidance (CLAUDE.md, no-path-scope rules) grows
by accretion — each session adds a rule, nothing is removed, signal-to-noise
drops, and compliance degrades. Counter it structurally:

- A hard size budget (the official docs recommend under 200 lines with workflow
  instructions moved to skills; the personal target is deliberately stricter).
- A new standing rule earns promotion by being cited repeatedly in session
  retrospectives — not by sounding wise.
- Rules never cited across many sessions are candidates for removal or demotion
  to an on-demand doc.

The budget is an _adherence_ budget, not a token budget. With prompt caching,
always-loaded config is a cache read on nearly every call, so its token cost is
negligible; the real cost is instruction adherence, which degrades with the
number of simultaneously applicable constraints. The rule system needs the same
right-sizing discipline as the code it governs.

### Path-scoped rules

- **`@path` imports are eager, not lazy.** `@file` imports in CLAUDE.md expand
  at launch and always consume tokens — an organizational tool, not a
  lazy-loading mechanism.
- **Path-scoped rules are the right lazy-loading mechanism.** They trigger
  mechanically when Claude opens a matching file, and fire `InstructionsLoaded`
  with `path_glob_match` — fully visible to hooks. Autonomous on-demand doc
  loading (Claude reading a doc on its own) is invisible to hooks.
- **Always-loaded rules (no `paths:`) share the CLAUDE.md context budget.** Keep
  them tight; critical rules stay in CLAUDE.md rather than fragmenting across
  rule files.
- **Timing nuance:** path-scoped rules trigger on file read, not on intent. This
  is acceptable — by the time Claude is writing or editing code, it has already
  read the relevant file.
- **Non-file-type triggers** (entering prototype mode, recovery) have no
  mechanical loading hook; the relevant guidance lives in CLAUDE.md or is pulled
  in by the workflow skill that handles the situation.

**Cross-language style stays in CLAUDE.md.** Migrating it to a path-scoped
`code-style.md` was evaluated and rejected. Always-loaded config is a cache read
on nearly every call, so its token cost is negligible; the real cost is
instruction adherence, which degrades with the number of simultaneously
applicable constraints, not with token share. In a coding session a path-scoped
style file loads anyway, so scoping reduces nothing where constraint load is
highest — and it would extend the Write gap (path-matched rules load only when a
matching file is read) to all style rules. Persistent violators graduate to
hooks rather than relocating prose.

**`InstructionsLoaded` hook:** Fires when a CLAUDE.md or `rules/*.md` file is
loaded, with the load reason (`session_start`, `path_glob_match`, `compact`,
etc.), file path, and trigger file. Observability only — no decision control.
Critical gap: does _not_ fire for `@file` imports or autonomous `Read` calls.
Primary value: catching systemic issues — rules loading when they shouldn't, or
failing to load when they should. Not yet designed.

### Hooks

- `SessionStart` → load handoff doc if present, so prior session context is
  available without manual `@`-referencing.
- `PostToolUse` on Edit/Write → run linter (ruff + mypy for Python), pipe output
  back so Claude can self-correct without a re-read.
- `PostToolUse` on Edit/Write of `*.md` → format the touched file immediately
  (`claude/hooks/format-markdown-on-edit.sh`). Rationale: the Stop-time format
  pass rewrote files after the turn ended, so follow-up Edits anchored to stale
  pre-format wording and failed. Formatting at edit time means the harness shows
  the rewrap before the next Edit anchors; the Stop-time pass stays as a safety
  net for files changed by other means.
- Explicit blocklist in settings.json for dangerous git operations
  (`git push --force`, `git reset --hard`, `git branch -D`, etc.) — hard block,
  not advisory. Non-dangerous git operations are handled by existing
  settings.json allow/prompt configuration.
- `deny: ["Bash(git commit *)"]` enforces no-auto-commit as a hard rule. In
  prototype mode (`prototype/*` branch), this deny rule is lifted so Claude can
  commit freely.

### Memory vs. docs

Strict separation:

- **Docs** — stable, intentionally designed rules. The constitution.
- **Memory** — observed, evolving facts about the user, the project, and
  corrections to Claude's behavior. The case law.

Memory files can reference docs but never duplicate or replace them. Memory MCP
servers were considered for automatic cross-session persistence but rejected:
automatic persistence risks injecting stale or irrelevant context, and the
auto-memory system already in place covers the memory layer without them.

### Skills vs. rules

- **Rules** are for persistent guidance that should always be present in context
  (or always present when a matching file is open). They load automatically.
- **Skills** are for task-specific instructions that are only relevant
  sometimes. They load on demand when the user invokes them. Use skills for
  workflow docs, not standing constraints.

**Skill frontmatter defaults:**

- **description**: the one field every skill needs — always in context (shared
  budget ≈1% of the window, ≤1,536 chars per skill) and what lets Claude
  proactively suggest the skill. Write it with trigger phrasing. Skip
  `when_to_use`, which appends to the same budget for little gain.
- **allowed-tools**: list the narrow tool set the skill needs, so a routine run
  doesn't generate permission prompts. Deny rules and hooks still apply.
- **model / effort**: omit — inherit the session's settings unless a skill is
  clearly mismatched with them.
- **disable-model-invocation**: only for skills the user must trigger; proactive
  suggestion is usually the point.
- **user-invocable: false**: for Claude-only helper skills.
- **context: fork**: for self-contained work that doesn't need the live
  conversation. Never for introspective or interactive skills — `/wrap-session`
  reflects on the session itself, and `/distill` walks the user through an
  approval conversation; both run inline.

### Linters vs. rules

"Never send an LLM to do a linter's job." Concrete style rules (line length,
naming conventions, import order) belong in linter config (ruff, mypy), not in
rule files. Rule files are for guidance the linter cannot enforce —
architectural principles, tradeoff preferences, context-dependent judgment
calls.

---

## Working agreement

### Approval, review, and git

**Approval philosophy:**

- Regular mode means step-by-step approval: the user confirms each consequential
  action through the permission prompt.
- Auto mode means autonomy within granted scope: Claude acts without prompts,
  bounded by what the conversation has authorized or restricted, by background
  safety checks, and by hard deny rules.
- Grants and restrictions established in conversation bind in both modes.

**Review and ownership:**

The review's purpose is the user's ownership of durable artifacts: by default,
every line maintainable solo without AI (the Code ownership requirement); for
low-risk units the floor is ratifying the key decisions. Two aims are held in
tension — Claude working independently for long stretches, and the user staying
in the ownership loop. The earlier model placed approval gates during
construction; it reviewed churn before the shape settled, fought the terminal as
a code-reading surface, and broke the independent-work flow.

The model instead is a post-hoc, attention-routing walkthrough:

- Claude works end-to-end, producing an uncommitted diff — the independent
  stretch, free of per-chunk gating.
- Before presenting it, Claude runs a self-review-and-fix pass so the user's
  attention lands on cleaned code, not an obvious-issue draft. `/code-review`
  (local, `--fix`, effort scaled to risk) is the tool — it covers correctness
  bugs and reuse/simplification/efficiency cleanups; `/simplify` is the
  quality-only lighter option. `/review` (pull-request oriented) is excluded:
  the process is fully local, with no GitHub PRs. The cloud `ultra` effort is
  not the default.
- Claude then presents a review map in chat: the pending diff partitioned into
  logical units — "logical pull requests," one coherent concept each — every
  unit carrying a short description, a risk tier with recommended review depth
  and a one-line why, and pointers to the locations to read. Claude proposes the
  overall weight (light skim vs. full walkthrough); the user adjusts.
- The user reads the actual code in their editor or diff tool — the terminal is
  a poor surface for reading code, so chat holds only the navigational map. The
  risk labels route attention: fly through low-risk units, slow to line-by-line
  on high-risk ones.

Review precedes the commit, preserving clean history (the discarded alternative
was commit-as-you-go with post-hoc review, rejected to avoid a messy log). The
logical grouping is an attention lens over the single pending diff, not a
commit-structuring device; commit granularity follows the Git rules. All durable
pieces are reviewed regardless of size; Claude proposes the weight per artifact,
so trivial changes get a skim and substantial or risky ones get the full
walkthrough.

Operative wording — the behavioral rule that makes Claude propose the map when
durable work finishes, and the skill that drives the walkthrough — lives in the
dotfiles config (source of truth). The exploration→production exit runs this
same flow over the cleaned-up reimplementation; it is the natural reassessment
moment.

**Git operations:**

- Claude may stage changes freely.
- Commits follow the approval philosophy: in regular mode the permission prompt
  is the per-commit gate — it shows the drafted message — and auto-mode commits
  stay within granted scope (e.g. ask-first repos remain ask-first). This is the
  built-in mode semantics for a command matching no permission rule, so no
  settings entry records it. Rules cannot be mode-conditional (an `allow` would
  remove the prompt in regular mode, an `ask` would add prompts in auto mode),
  which is why a once-planned `git commit` deny rule was dropped — it would also
  block user-directed commits.
- Commit history is deliberately durable: preserving intermediate states is a
  primary reason for committing, so amending is reserved for noise — states with
  no standalone value — and uncertainty resolves toward stacking another commit,
  never toward rewriting. Operative rule in the global CLAUDE.md (Git).
- Destructive git commands (force and delete pushes, hard resets, forced branch
  deletion, clean, stash drop/clear) are hard-blocked by deny rules in
  `settings.json` regardless of mode.
- Pushes to shared remotes require explicit user direction.
- GitHub credentials available to Claude are fine-grained access tokens, minted
  by the user per repo with minimal permissions.
- Server-side branch protection backstops the local deny rules: every branch
  must block force pushes and deletion and require linear history, enforced by
  one or more active rulesets. `~/.claude/scripts/gh-protect.sh` (dotfiles)
  verifies this by function — checking the repo's active, all-branch rulesets
  enforce those rules, regardless of name or how they are split — and only
  reads. Creating a ruleset is the user's job via the GitHub UI; on a gap the
  script names what is missing and prints a config to create. A token that could
  write rulesets could also remove them, so that power stays off the tokens
  Claude holds.

### Scope discipline

- Changes outside the explicit request require the user's approval before being
  made. Adjacent fixes, refactors, and improvements are never silently included
  — when something adjacent is noticed, flag it and ask.

### Disagreement and ambiguity

**Disagreement and pushback** — when Claude believes the requested approach is
wrong or suboptimal, the response scales with severity:

- Minor concern: note it briefly and proceed.
- Significant concern: stop and ask before executing.
- Clear mistake: refuse to execute and explain why.

Pushback is raised before writing code, not after.

**Ambiguity handling:**

- When a request is low-ambiguity and the work is easily reversible: proceed
  with a clearly stated assumption.
- Otherwise: clarify before executing. Do not write code based on a guess when
  the stakes of guessing wrong are significant.

### Session flow and planning

**Default flow:** gather requirements → spec → task queue → execute end-to-end →
self-review and fix → present the review map → the user reviews and owns →
commit. Code review is post-hoc rather than gated per increment (see Review and
ownership). The "one coherent concept at a time" unit survives as the
partitioning of the review map, not as a construction-time gate; each unit is
still described by what it adds. When there's too much to work through
comfortably at once — research findings, decisions, a long review — break it
into pieces and work through them iteratively.

**Planning artifacts — two files with distinct jobs:**

1. **`spec.md`** — the what and why, for someone building or changing the
   project: requirements, architecture decisions and their rationale, data
   models, edge cases, testing strategy. Durable — still true after the
   implementation ships; carries no status. Inline (in conversation) for smaller
   features. `README.md` serves the complementary audience — someone using the
   project — and stays fully self-contained; the spec may reference the README,
   never the reverse.
2. **`tasks.md`** — the per-project tracker (format: `rules/markdown.md`).
   Structure scales with need: a flat checklist of to-dos suffices for most
   projects; phases with goals and checkbox statuses appear when work needs
   sequencing, with a flat backlog section for unsequenced items. Completed work
   can be summarized or pruned once it stops informing the remaining work; git
   preserves the detail.

The format conventions stay consistent across projects; how much structure to
use, what enters the tracker (e.g. in-session task breakdowns, which usually
live in chat), and how aggressively to prune are per-project judgments — keep
the process light. Create `tasks.md` when loose ends start accumulating, and
`spec.md` when design decisions need a durable record.

The spec is written and approved before tasks are queued. This order matters: a
task breakdown written before the requirements are clear will encode the
misunderstanding. Iterating on a spec is cheap; iterating on a queue that rests
on a wrong spec is expensive. For any non-trivial implementation session, start
with requirements gathering before proposing anything: Claude asks structured
questions about edge cases, tradeoffs, and hard parts; the discussion stays
open-ended until the approach is clear; only then does Claude compile a spec,
get approval, and queue the tasks. This is the default, not a fallback for large
features.

The built-in plan mode (`Shift+Tab`) explores and proposes before discussion —
the opposite order — so it is not the primary path; skip it in favor of the
conversational flow above. Plan mode can now ask clarifying questions before
finalizing a plan, which narrows that gap; worth re-evaluating. `/ultraplan`
(cloud-based, browser review) may complement or replace this once evaluated; not
yet vetted.

**Parallel sessions (writer/reviewer):** Running one session to implement and a
separate session to review eliminates authorship bias, and is well-regarded in
the community. The built-in `/code-review` skill (configurable effort; can post
findings as PR comments or apply fixes) covers much of this goal without a
second session — and is adopted as the self-review-and-fix step in the
review-ownership model (see Review and ownership), which closes the earlier open
question of evaluating it before designing a dedicated writer/reviewer flow.

### Transparency and explaining decisions

- Progress, findings, and current confidence level must be visible throughout
  execution — not just summarized at the end. The user should never be left
  wondering what Claude is doing or how well it's going. The cadence decision —
  pace narration by investigation structure, not a fixed clock interval — lives
  in the global CLAUDE.md (Interaction style).
- Claude explains its own choices during planning and execution: what approach
  was taken, what alternatives were considered, and why. This is distinct from
  upskilling — it's about the user understanding the work, not learning better
  approaches. The level of explanation is proportional to non-obviousness:
  trivial choices need none; non-obvious tradeoffs do.

### Runaway prevention and recovery

Recovery should be cheap enough that taking it is easy. The user's natural
instinct is to debug in place; this is appropriate for shallow problems but
token-inefficient for deep confusion or a wrong direction. Two distinct runaway
cases, handled differently:

**Planned tasks** — the plan approval flow is the primary defense. The blast
radius of any misunderstanding is bounded to one chunk, since each chunk
requires approval before the next begins. The confidence gate is embedded in the
plan format: every plan includes Claude's understanding of the problem, intended
approach, confidence level, and open unknowns.

**Mid-session incidental prompts** — the main risk zone. A small-seeming prompt
("quick sanity check", "just verify X") has no plan step and no approval gate.
This is where Claude can silently spend 50%+ of a session's token quota going
nowhere useful, with the user unable to tell at the 3-minute mark whether to
interrupt. Two mechanisms address it:

1. **Effort budget.** When a prompt is framed as small or incidental, Claude
   treats it as an implicit scope constraint. If the task turns out to require
   more investigation than the framing suggested — more files, multiple failed
   approaches, a constraint that looks impossible — Claude pauses, reports
   current findings and an estimate of remaining work, and explicitly asks
   whether to continue. It does not escalate effort silently.
2. **Explicit permission to fail.** "This seems infeasible" and "I'm stuck —
   this could use active collaboration" are first-class, acceptable outcomes.
   The social pressure to produce something plausible is a known failure mode
   and must be directly counteracted.

**During investigation**, narration should be findings-oriented, not
action-oriented. "I found X, which suggests Y, so I'm now checking Z" gives the
user enough signal to interrupt intelligently. "Reading file X" does not.

**Concrete tactics:**

- Before exploring risky or uncertain territory, commit the working state. With
  a clean baseline, a fresh session can be briefed in one sentence.
- Debug in place for shallow problems; fresh session for deep confusion.
- After two failed attempts on the same issue, stop and diagnose the root cause
  before retrying — don't rerun unchanged commands or iterate patches on weak
  understanding. Name whether a fix addresses the root cause or a symptom, and
  let the user choose.

**Known failure modes:**

- **Dead code accumulation**: rewrites leave old implementations alongside new
  ones. Run a targeted cleanup pass; don't let it accumulate across sessions.
- **Premature abandonment**: Claude declares partial success on large tasks.
  Mitigate by including explicit success criteria in the prompt.
- **Kitchen sink sessions**: mixing unrelated tasks degrades performance as
  context fills. `/clear` between unrelated tasks, not just when running out of
  room.
- **Post-compaction regression**: context quality degrades after compaction;
  Claude re-reads files already seen, loses constraints. If severe, `/clear`
  with a fresh prompt beats continuing on degraded context.

### Constraint persistence

Rules and constraints established at the start of a session must remain honored
throughout. `CLAUDE.md` and `rules/` files are always re-injected after
compaction — not at risk. The real concern is `docs/` files, which load
on-demand: after compaction, Claude may retain a belief that it read a doc while
the actual content has been trimmed from context. This is not a priority concern
— compaction only affects long-lived sessions, and the expected session style is
short and focused. If it becomes an issue, the mitigation is to keep
load-bearing content in `CLAUDE.md` or `rules/` rather than `docs/`.

### Independent verification

- Mechanical checks (linters, type checkers, test suites) catch errors
  independently of Claude's confidence — valuable precisely because they don't
  share Claude's blind spots. Not always practically feasible: when tools exist
  and are easy to run, the workflow takes advantage of them; when they don't,
  this isn't a blocker.
- Test files deserve extra scrutiny: Claude will edit tests to make wrong code
  pass rather than fixing the code. Test changes are reviewed with the same care
  as core logic.
- TDD is worth considering for every project as a structural defense against
  test manipulation: tests written before code can't be retroactively adjusted
  to pass wrong implementations. Don't enforce it dogmatically — it won't always
  fit.

### Upskilling

Flagging meaningful improvement opportunities is a first-class goal, not a
nice-to-have. This applies to user-written code as well as Claude-generated code
— no formal review process, but noticed issues should be surfaced. Apply the
80/20 rule: high-leverage improvements only; skip micro-optimizations unless
asked. The highest-leverage domain is Claude Code features and the tooling
ecosystem (shallow expertise, most upside).

Delivery mechanism: inline by default — a note at the moment it's relevant,
whenever the cost to flow is low; a turn-end note loses the moment's context.
Size the note to the topic: tight articulation keeps notes read rather than
skimmed, but a complex topic may take several lines — the goal is education, not
brevity. The `/wrap-session` step complements inline delivery by reviewing the
session as a whole for patterns that weren't visible, or not in the attention
set, during the turns.

Built-in skills worth incorporating once familiar with their behavior:
`/simplify` (post-write quality and reuse pass), `/review` (pull request
review), `/code-review` (diff review at configurable effort), and
`/security-review` (security pass over pending changes).

### Soliciting user input

When Claude needs a decision from the user, use the `AskUserQuestion` tool with
structured multiple-choice options and a write-in fallback. This produces
tighter answers than open-ended back-and-forth. Default to this UI for: choosing
between design approaches, calibrating behavior, or gathering preferences at the
start of a design-heavy session. Ask at most 4 questions at once; group related
choices. The pattern that worked well for requirements gathering: brainstorm
dimensions, gather preferences via structured questions, build requirements,
research, capture.

---

## Subsystems

### Token and context health

Goals: never exhaust quota mid-session; keep sessions navigable as they grow so
the cost of a fresh start stays low. Waste is avoidable iteration — retry loops,
scope drift, rework, speculative exploration — not output length. Never optimize
gameable surface metrics (raw token counts, read counts, response length) at the
expense of quality.

**Efficiency model:** quota waste in small interactive sessions is almost never
about output length; it is iteration that shouldn't have happened. Recurring
failure modes:

- Retry loops on validation errors — editing before reasoning through the whole
  change. The hook should confirm, not discover.
- Misalignment before execution — one clarifying question beats one correction
  loop.
- Scope drift — touching files the task didn't require; expansions surfaced
  after the fact instead of before.
- Context drift in long sessions — stale assumptions about signatures and files.
  Re-read before major edits late in a session; compact proactively.
- Overengineering — abstractions the problem doesn't need. Right-size to the
  current project's scale, not hypothetical future scale.
- Persistent artifact overhead — always-loaded files accrete a per-session tax
  (see CLAUDE.md and size discipline).

Efficiency pressure has its own failure modes to guard against: timidity
(symptom fixes framed as "minimal footprint"), premature convergence (first
plausible approach, alternatives unexplored), undervalidation, over-compression
(plans too terse to prevent correction turns), and metric gaming. The primary
question is always "did the session produce a good outcome?" — metrics are
diagnostic tools, not targets.

The session-log token quantification — the measurement approach, the SessionEnd
hook that automates it, its decisions, and the per-type baselines — is
wrap-session-scoped and lives in `skills/wrap-session/notes.md`.

Operative guidance on model/effort selection, session hygiene, and reducing
token spend lives in CLAUDE.md and the token-efficiency rules — general Claude
Code practice, not decisions unique to this system.

### Exploratory mode

Production rigor is the default; exploratory mode holds code to a lighter
quality bar — a spike, a feasibility probe, feeling out a design. The user
signals exploration (Claude may propose it; the user confirms before entering),
and Claude eases style, review, and testing rigor while it lasts. Operative
wording lives in the global CLAUDE.md (Exploratory mode).

Exploratory code lives under a `scratch/` directory — a durable, visible marker
of its intended bar, chosen over an invisible internal choice so the distinction
survives into later sessions and is legible at a glance. A directory was chosen
over a filename suffix or a file-level comment because a path is the most
visible form and the bar travels with every reference; the always-on
exploratory-mode rule already ties the `scratch/` path to the relaxation, so it
fires without a separate path-scoped rule. `scratch/` is deliberately not
gitignored — the goal is to delineate code by its intended quality bar, not to
keep exploratory code out of history; committing it is often useful. Graduation
is moving a file out of `scratch/` into the production tree, which runs the
ownership review (see Review and ownership) — the natural reassessment point.

A structural design was considered and rejected: a `/prototype` skill creating a
git worktree on a `prototype/*` branch, with hooks reading the branch name to
relax — making prototype code impossible to accidentally commit as production.
File-suffix naming (`_prototype.py`) was rejected within that design as relying
on naming discipline; the worktree was its structural alternative. The whole
structural layer was then dropped: the failure it guards — committing throwaway
code as production — is rare in solo hobby work and not worth the ceremony of a
mandatory worktree, a branch flag, and a three-way exit skill. The built-in
`EnterWorktree` remains available for the occasional case where isolation
genuinely helps, so no custom worktree skill is needed.

### Build vs. buy

Evaluated [superpowers](https://github.com/obra/superpowers) as an alternative
to building this system from scratch. It offers sophisticated subagent
orchestration, git worktree isolation, and a validated 8-stage workflow.

Decision: build custom. The fatal conflict is the autonomy philosophy —
superpowers is designed for multi-hour autonomous runs with human review at the
end; this system requires human approval throughout every chunk and every
commit. That's not a configurable option; it's the organizing principle of each
system.
