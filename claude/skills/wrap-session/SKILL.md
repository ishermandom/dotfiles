---
description: End-of-session protocol. Run when wrapping up a session.
allowed-tools: Read, Edit, Write, Bash
---

Work through each step in order.

If wrap-session already ran earlier in this session, evaluate only the work
since that run — otherwise the session log double-counts the same findings.

## 1. Session naming

Evaluate whether this session is worth naming. Suggest `/rename <name>` only for
sessions with incomplete work or context worth returning to. Skip for one-offs
and fully completed tasks — most sessions don't need a name.

## 2. Upskilling

Help the user use Claude Code and their other tools more effectively over time.
Inline notes during the session are the default delivery (per CLAUDE.md); here,
review the session as a whole for what the in-the-moment notes missed — patterns
visible only in aggregate, or outside the turn-by-turn attention set:

- A product feature that would have helped (a Claude Code capability, flag,
  slash command, hook, or skill they aren't using)
- An efficiency tip — a faster or lower-friction way to do something they did
  manually or repeatedly
- An interesting pattern that came up that's worth remembering or internalizing

Suggest one or two takeaways, concretely tied to moments from this session. This
is chat-only guidance for the user to internalize — don't persist it anywhere.
Skip if nothing stands out.

## 3. Durable context routing

Identify what a future session would need from this one, and write each piece
into the durable file where that session would look for it. Do not write
narrative session reports into project files: narrative belongs in git history
and chat, and a project-local log entry is where context goes to get stale.
(Efficiency reflection goes to the global session log — step 4.)

- **Pending work, next steps, and decisions about them** → the project's
  `tasks.md` (or plan doc): update statuses, add tasks, and attach
  `Rationale:`/`Note:` annotations per the plan-document rules.
- **Approaches tried and abandoned** → a `Note:` on the relevant task, or a
  `[-]` dropped task, so the dead end isn't retried.
- **Findings or constraints that outlive any one task** → the project file a
  reader would consult for that topic (e.g. a Findings section, README, spec).
- **Accomplished work and files modified** → nowhere: commit messages and git
  history already record these.

If a piece of durable context fits none of the project's existing durable files,
propose a new file — name and scope — and confirm both with the user before
creating it.

## 4. Reflection and session log

Reflect adversarially: assume meaningful inefficiencies occurred unless evidence
suggests otherwise, and prioritize identifying avoidable waste over highlighting
accomplishments. Cover:

- _Token efficiency_: diagnose the session's main cost drivers from observable
  evidence — file reads (`wc -c` gives sizes when comparing), subagent output
  volume, other large tool results. Identify at least one concrete case of
  higher-than-necessary consumption, with a diagnosis (_why_ did this happen?)
  and a mechanism (_what specifically changes_ to prevent it?).
- _Attention efficiency_: was context well-focused on the right things? Were
  there tangents, unnecessary back-and-forth, or work that could have been
  deferred? Each identified failure needs a diagnosis and mechanism specific
  enough that a skeptic couldn't dismiss them as obvious. "Do better next time"
  is a wish, not a reflection.
- _Corrections_: moments the user redirected Claude — what was misunderstood,
  and what earlier signal would have caught it.
- _Rules and loaded context_: standing rules and the other artifacts that loaded
  this session (CLAUDE.md sections, rules files, docs, skill instructions) —
  which actively shaped the session, were violated, should have fired and
  didn't, or loaded without earning their tokens. One session is citation data,
  not a verdict: demotion and removal decisions belong to distillation across
  many sessions.
- _Config size_: spot-check the cost side of loaded context — `wc -l` on
  always-loaded files, flagging outliers — and, when something looks bloated,
  suggest the user run `/context` (per-feature context breakdown) and `/usage`
  (per-skill/subagent/MCP cost attribution) for the authoritative measure.
  Record both signals — line counts and `/context` shares — so their relative
  effectiveness can be compared over time.

Present the highlights in chat, then append an entry to
`~/.claude/logs/sessions.md` (create the file if missing):

- Heading: date, project, and session type (coding / debug / refactor / planning
  / explore), followed by a scope line of countable facts — e.g.
  `4 files modified · 2 correction turns · 11 file reads`. Scope facts are
  events counted from the conversation, not token figures.
- Sections, each omitted when empty: **Inefficiency** (top 1–3 sources of
  avoidable effort, each with the earliest signal that should have triggered a
  course change), **Corrections**, **Adjustments** (at most three proposed
  behavioral changes — specific and narrowly scoped, not "plan better"),
  **Rules**.
- Size scales with the session: 1–2 lines for a short clean session, ~10 lines
  typically, at most ~25 for a complex one. The budget forces selectivity; it is
  not a target.

All counts in the entry are directional diagnostics — questions to investigate
when they drift across sessions, never targets to optimize.

To append cheaply, use a Bash heredoc (`cat >> <log> <<'EOF' … EOF`) — an append
needs no prior read, while the Edit tool requires Reading the whole file first.

A mechanism that generalizes beyond this session belongs in memory or the
relevant rules file — handle that in the Learning step.

If ~10 or more session entries have accumulated since the last distillation
marker in the log, suggest running the distill skill.

## 5. Pending commits

If in a git repo, run `git status`. If there are uncommitted changes, remind the
user to commit before closing the session.

## 6. Learning

Update memory files with anything worth persisting: corrections, preferences,
project facts. If a `~/.claude/docs/` file needs updating, flag it and ask
before editing.

## 7. Reviewer session

If production code was written, offer:

> "Consider a reviewer session: open a fresh session with the relevant files in
> context and run `/review`."

## 8. Clear, compact, or continue

Close with a genuine judgment on what to do with this session next. Weigh what
is in context now, what the next task needs, and the cheapest path to it:

- **Clear** when the next task is unrelated and nothing needs to carry forward —
  eliminates re-ingestion cost entirely.
- **Compact** only when the next task genuinely needs live context from this
  session (mid-task state, open decisions, active debugging). Compaction defers
  re-ingestion cost to the next turn; it does not eliminate it.
- **Continue** only when context is genuinely small and the next task is a
  direct extension.

Give 2–3 sentences: the current context state, what the next task likely needs,
and the recommendation with its reasoning.
