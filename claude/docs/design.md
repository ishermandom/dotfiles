# Collaboration system design record

A searchable record of the design decisions behind the personal Claude Code
collaboration system, and the rationale for each. The primary consumer is a
Claude session asking "why is X set up this way" — grep for the topic rather
than reading front to back. The operative configuration under `~/.claude/` is
the source of truth for behavior; this record holds only the why, and never
mirrors config text. Rationale scoped to a single skill lives in that skill's
companion `notes.md`, not here.

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
  acceptable outcomes. Producing a plausible-looking result to meet a perceived
  expectation is always worse than surfacing the problem.

### Use-case profile

- Small personal hobby projects, driven through interactive sessions, solo —
  consistency comes from personal style guides, not team norms.
- Mostly long-lived: a handful of projects revisited over months or years, so
  cross-session continuity matters more than raw speed.
- Polyglot: Python, shell, and TypeScript/JS today; Rust likely soon.
- Risk surface: code runs locally, so the blast radius of a bug is the user's
  own time and machine. Production-grade rigor is still a goal in itself —
  keeping professional skills fresh is a primary purpose of these projects.

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

Project-scoped additions live under `projects/<project>/` (a project CLAUDE.md
and the auto-memory store). The directories themselves are the file-layout
source of truth.

### CLAUDE.md and the attention budget

CLAUDE.md holds core principles, critical rules hooks cannot enforce, and
cross-language style; detailed per-language rules live in `~/.claude/rules/` as
path-scoped files that load mechanically when a matching file is opened.

The budget that governs CLAUDE.md is an _attention_ budget, not a token or line
count. With prompt caching, always-loaded config is a cache read on nearly every
call, so its token cost is negligible; the real cost is instruction adherence,
which degrades with the number of simultaneously applicable constraints.
Always-loaded guidance grows by accretion — each session adds a rule, nothing is
removed, signal-to-noise drops — so the counter-pressure is structural:

- A new standing rule earns promotion by being cited repeatedly in session
  retrospectives — not by sounding wise.
- Rules never cited across many sessions are candidates for removal or demotion
  to an on-demand doc; rules that never fire get dropped (the in-session
  effort-level flag was removed on exactly this evidence).
- Persistent violators graduate to hooks rather than gaining more prose.

**Maintainer notes**: HTML comments are stripped from path-matched rules-file
injection only (sentinel-verified 2026-06-13 and again 2026-07-03). CLAUDE.md
injection does _not_ strip them — observed directly 2026-07-03, correcting an
earlier over-generalization of the rules-file result — so CLAUDE.md rationale is
either a one-clause inline why or lives in CLAUDE.md's companion notes file
(`docs/claude-md-notes.md`, mirroring the skills pattern). Docs and `SKILL.md`
enter context verbatim as well. Operative convention:
`rules/claude-configuration.md` (Maintainer rationale); skill rationale goes in
a companion `notes.md`.

**Cross-language style stays in CLAUDE.md** (evaluated and rejected moving it to
a path-scoped `code-style.md`): in a coding session a path-scoped file loads
anyway, so scoping reduces nothing where constraint load is highest — and it
would extend the Write gap (path-matched rules load only when a matching file is
read) to all style rules. The residual gain — a lighter CLAUDE.md in docs- or
config-only sessions — stays small, because most sessions are coding sessions.

### Path-scoped rules

- **`@path` imports are eager, not lazy** — they expand at launch and always
  consume tokens; an organizational tool, not a lazy-loading mechanism.
- **Path-scoped rules are the right lazy-loading mechanism**: they trigger
  mechanically on file read and fire `InstructionsLoaded`, visible to hooks.
- **Timing nuance**: they trigger on read, not intent — acceptable, since by the
  time Claude edits code it has read the relevant file. The residual gap
  (`Write` of a new file loads nothing) is covered by a CLAUDE.md rule.
- **Non-file-type triggers** (e.g. entering exploratory mode) have no mechanical
  loading hook; that guidance lives in CLAUDE.md or a skill.
- **`InstructionsLoaded` observability**: implemented as a logging hook
  (`hooks/log_instructions_loaded.py`) so rule-loading can be debugged after the
  fact. Known limitation: the event does not fire for `@file` imports or
  autonomous `Read` calls.

### Hooks

`settings.json` is the source of truth for what runs when; this record keeps
only the durable design choices behind it:

- **Formatting Markdown at edit time, not just Stop**: the Stop-time pass
  rewrote files after the turn ended, so follow-up Edits anchored to stale
  pre-format wording and failed. Formatting immediately after each edit means
  the harness shows the rewrap before the next Edit anchors. The same
  anchor-stability rationale drives the Python prose-reflow hook.
- **Tests and type checks at Stop, not per edit**: a single turn often has
  multiple interdependent edits; mid-turn runs produce false failures.
- **Stop-hook failures surface to the user** (`continue: false`), not as a
  `decision: block` auto-re-invoke: a block can spin forever when Claude cannot
  fix the failure, guarding that is out of scope for now, and the user-prod
  workaround is trivial.
- **Destructive git operations are hard-blocked**: bare-form deny entries in
  settings.json are the floor; the `gate_git.py` PreToolUse hook is the
  flag-aware extension (it also auto-allows provably read-only invocations). The
  overlap is deliberate — the settings entries still apply when the hook defers
  or degrades.
- **No `git commit` deny rule**: permission rules cannot be mode-conditional (an
  `allow` would remove the regular-mode prompt, an `ask` would add prompts in
  auto mode), and a deny would block user-directed commits. The built-in mode
  semantics — prompt in regular mode, scoped autonomy in auto mode — are the
  commit gate, so no settings entry records it.

### Memory vs. docs

- **Docs** — stable, intentionally designed rules. The constitution.
- **Memory** — observed, evolving facts and corrections. The case law.

Memory files can reference docs but never duplicate or replace them. Memory MCP
servers were rejected: automatic persistence risks injecting stale or irrelevant
context, and the built-in auto-memory covers the layer.

### Skills vs. rules

Rules are persistent guidance, loaded automatically (always, or on a matching
file). Skills are task-specific workflows, loaded on user invocation — use them
for workflow docs, not standing constraints.

**Skill frontmatter defaults**: `description` is the one field every skill needs
— always in context (shared budget ≈1% of the window) and what enables proactive
suggestion, so write it with trigger phrasing; skip `when_to_use` (same budget,
little gain). `allowed-tools`: omit — unenforced in inline skills (verified
2026-07-03: no restriction and no permission pre-approval; a slash-command-era
pre-approval intent that never functioned — Claude Code issues #18837, #14956);
`disallowed-tools` is the enforced mechanism if a skill must shed tools.
`model`/`effort`: omit — inherit the session's. `disable-model-invocation`: only
for skills the user must trigger. `context: fork`: never for introspective or
interactive skills — wrap-session reflects on the live session and distill runs
an approval conversation, so both run inline.

### Linters vs. rules

"Never send an LLM to do a linter's job." Concrete, mechanically checkable style
(line length, import order) belongs in linter config (ruff, mypy); rule files
carry only what a linter cannot enforce — architectural principles, tradeoff
preferences, judgment calls.

---

## Working agreement

### Approval, review, and git

**Approval philosophy**: regular mode means step-by-step approval through the
permission prompt; auto mode means autonomy within the scope the conversation
has granted, bounded by deny rules and safety checks. Grants and restrictions
established in conversation bind in both modes.

**Review and ownership**: the review's purpose is the user's ownership of
durable artifacts — every line maintainable solo by default; for low-risk units,
ratifying the key decisions is the floor. Construction-time approval gates were
tried and rejected: they reviewed churn before the shape settled, fought the
terminal as a code-reading surface, and broke independent-work flow. The adopted
model is a post-hoc, attention-routing walkthrough:

- Claude works end-to-end, producing an uncommitted diff.
- Before presenting it, Claude runs a self-review-and-fix pass
  (`/code-review --fix`, effort scaled to risk; `/simplify` for quality-only;
  never cloud `ultra` here) so the user's attention lands on cleaned code.
- Claude presents a review map: the diff partitioned into logical units
  ("logical pull requests"), each with a risk tier, recommended review depth, a
  one-line why, and where to read. The user reads real code in their editor;
  chat holds only the map.
- Review precedes commit, keeping history clean (commit-as-you-go with post-hoc
  review was rejected as producing a messy log). The unit partition is an
  attention lens, not a commit-structuring device.

Operative wording lives in CLAUDE.md (Review approach) and the
`ownership-walkthrough` skill. The exploratory→production graduation runs this
same flow.

**Git**: commit history is deliberately durable — preserving intermediate states
is a primary reason for committing, so amending is reserved for noise and
uncertainty resolves toward stacking commits. Destructive operations are
hard-blocked (see Hooks). Pushes require explicit user direction; credentials
are per-repo fine-grained tokens with minimal permissions. Server-side branch
protection backstops the local rules: `scripts/gh-protect.sh` verifies by
function that active rulesets block force-pushes and deletion and require linear
history — read-only by design, since a token that could write rulesets could
also remove them; creating rulesets stays a user action in the GitHub UI.

**Rejected: archive-ref preservation system.** An earlier iteration (crosswords,
2026-07-03) designed a fuller model for agent-heavy repos: long-lived branches
updated via merge-in rather than rebase (to avoid a force-push per update),
landed by rebase-and-reset onto `main`, with every rewritten-away or deleted ref
auto-archived to `refs/archive/<branch>/<timestamp>` by a GitHub Action, so
nothing superseded ever loses a discoverable name. Rejected for the simpler
model actually adopted, which sidesteps the problem rather than solving it:
branches are never pushed (only `main` pushes), so a rebased branch only ever
rewrites a local ref, recoverable from the local reflog like any local rebase;
`main` itself is only ever fast-forwarded, never rewritten. The archive
machinery was disproportionate infrastructure once that constraint removed its
reason to exist. Revisit if rebase-branch friction (repeated conflict
re-resolution on a long-lived branch) turns out to bite in practice, or if
branches ever need to be pushed for shared/parallel work.

**Rejected: first-parent-linear `main`.** Same iteration: landing branches as
merge commits on `main` (kernel-style), reading the clean line via
`git log --first-parent` instead of enforcing linearity structurally. Removes
all rebase/replay/archive machinery at the cost of losing GitHub's
linear-history enforcement and putting merge knots in the raw log. Passed over
on familiarity grounds — strict linearity matches the user's Chromium/Piper-
trained instincts — not because it's structurally worse; the explicit fallback
if strict linearity's per-landing friction proves higher than expected.

### Scope, disagreement, ambiguity

Operative rules live in CLAUDE.md (Scope in Review approach; Disagreement and
pushback, calibrated by consequence). The design stance: adjacent changes are
never silently included; pushback is raised at planning time, before code;
low-ambiguity reversible work proceeds on a stated assumption, everything else
clarifies first.

### Session flow and planning

**Default flow**: gather requirements → spec → task queue → execute end-to-end →
self-review and fix → review map → the user reviews and owns → commit. When
there is too much to work through comfortably at once, break it into pieces and
iterate.

**Planning artifacts**: `spec.md` carries the what and why (durable, no status);
`tasks.md` is the per-project tracker. Format conventions live in
`rules/markdown.md`; how much structure and pruning stays a per-project
judgment. The spec is approved before tasks are queued — a task breakdown
written before requirements are clear encodes the misunderstanding, and
iterating on a spec is cheap while iterating on a wrongly-founded queue is not.
Requirements gathering starts every non-trivial session; the `spec` skill drives
it.

Built-in plan mode explores and proposes before discussion — the opposite order
— so the conversational flow is primary; plan mode's newer clarifying-questions
support narrows the gap and is worth re-evaluating. `/ultraplan` remains
unvetted. A dedicated writer/reviewer two-session flow was closed as
unnecessary: `/code-review` adopted as the self-review step covers the goal
without a second session.

### Transparency

Progress, findings, and confidence stay visible throughout execution; the
narration-cadence rule (pace by investigation structure, findings-oriented)
lives in CLAUDE.md. Claude explains non-obvious choices — approach, alternatives
weighed, why — in proportion to their non-obviousness.

### Runaway prevention and recovery

Two distinct runaway cases, handled differently:

- **Planned tasks**: the plan approval flow bounds the blast radius to one
  chunk; every plan carries Claude's understanding, approach, confidence, and
  open unknowns.
- **Mid-session incidental prompts** — the main risk zone: a small-seeming
  prompt has no plan step, and Claude can silently spend a large share of the
  session going nowhere. Mechanisms: the framing of a prompt as small is an
  implicit scope constraint (Claude pauses and asks before escalating effort
  past it), and explicit permission to fail (see Foundations).

Recovery should be cheap enough that taking it is easy: commit the working state
before exploring risky territory; debug in place for shallow problems, fresh
session for deep confusion. The two-failed-attempts diagnosis rule is operative
in CLAUDE.md (Working method).

**Known failure modes** (watch for these): dead code accumulating across
rewrites; premature abandonment of large tasks (mitigate with explicit success
criteria); kitchen-sink sessions (clear between unrelated tasks);
post-compaction regression (if severe, a fresh session beats degraded context).

### Constraint persistence

CLAUDE.md and rules files are re-injected after compaction — not at risk. The
exposure is on-demand `docs/` content: after compaction Claude may believe it
read a doc whose content is gone. Accepted as low priority — sessions are short
and focused; the mitigation, if needed, is moving load-bearing content into
CLAUDE.md or rules.

### Independent verification

Mechanical checks (linters, type checkers, tests) catch errors independently of
Claude's confidence — valuable precisely because they don't share Claude's blind
spots; use them when practical. Test files deserve extra scrutiny: Claude will
edit tests to make wrong code pass, so test changes get the same review care as
core logic. TDD is worth considering per project as a structural defense — tests
written first can't be retro-fitted to wrong implementations — but is not
enforced dogmatically.

### Upskilling

Flagging improvement opportunities is a first-class goal, applying the 80/20
rule, with Claude Code features and tooling as the highest-leverage domain.
Delivery is inline by default with a wrap-session sweep for aggregate patterns;
operative wording in CLAUDE.md and the wrap-session skill.

### Soliciting user input

Structured `AskUserQuestion` rounds (max 4 questions, grouped, write-in
fallback) beat open-ended back-and-forth for decisions and preferences; the
pattern that works for requirements: brainstorm dimensions, gather preferences
via structured questions, build requirements, research, capture. Operative rule
in CLAUDE.md (Interaction style).

---

## Subsystems

### Token and context health

Goals: never exhaust quota mid-session; keep sessions navigable so a fresh start
stays cheap. Waste is avoidable iteration — retry loops, misalignment corrected
after execution, scope drift, context drift, overengineering — not output
length. Never optimize gameable surface metrics at the expense of quality; the
primary question is always "did the session produce a good outcome?"

Efficiency pressure has its own failure modes to guard against: timidity
(symptom fixes framed as minimal footprint), premature convergence,
undervalidation, over-compression, and metric gaming.

The measurement machinery (session log, SessionEnd token counting, per-type
baselines) is wrap-session-scoped and lives in `skills/wrap-session/notes.md`.
Operative guidance on session hygiene and token spend lives in CLAUDE.md.

### Exploratory mode

Production rigor is the default; exploratory mode relaxes style, review, and
testing while it lasts, entered only with user confirmation. Exploratory code
lives under `scratch/` — a path is the most visible, durable marker of the
intended quality bar, and it travels with every reference. Deliberately not
gitignored: the goal is delineating the bar, not keeping the code out of
history. Graduation is moving a file out of `scratch/`, which triggers the
ownership review.

Rejected alternatives: a filename suffix (relies on naming discipline) and a
structural `/prototype` worktree-plus-branch layer with hook enforcement — the
failure it guards (committing throwaway code as production) is rare in solo
hobby work and not worth a mandatory worktree, a branch flag, and a three-way
exit skill. Built-in `EnterWorktree` covers the occasional genuine isolation
need. Operative wording in CLAUDE.md (Exploratory mode).

### Build vs. buy

[superpowers](https://github.com/obra/superpowers) was evaluated as an
alternative to building this system. Decision: build custom. The fatal conflict
is autonomy philosophy — superpowers is designed for multi-hour autonomous runs
with review at the end; this system keeps the user in the loop throughout.
That's the organizing principle of each system, not a configurable option.
