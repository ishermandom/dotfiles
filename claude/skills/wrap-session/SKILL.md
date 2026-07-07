---
description: End-of-session protocol. Run when wrapping up a session.
---

Work through each step in order.

If wrap-session already ran earlier in this session, evaluate only the work
since that run — otherwise the session log double-counts the same findings.

This skill surfaces a lot, so the Concision rule (CLAUDE.md, Interaction style)
is especially load-bearing here. In chat, include only what the user might act
on, approve, or overrule — at the minimum length to evaluate it, cutting the
narrative behind a conclusion. Don't recap findings already discussed this
session; a step with nothing actionable produces no chat output — not even a
line noting it was skipped, didn't apply, or is already done. Don't confirm
default paths (naming not needed, no reviewer session, clearing is right): a
non-action is not a finding. Durable detail goes to its file, not chat.

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
- An effort-level mismatch — the session ran at a higher or lower effort setting
  than the task warranted (high effort on a trivial task, or the reverse).
  Suggest recalibrating the default for similar work next time

Suggest one or two takeaways, concretely tied to moments from this session. This
is chat-only guidance for the user to internalize — don't persist it anywhere.
Skip if nothing stands out.

## 3. Durable context routing

Read `~/.claude/skills/session-context-routing.md` and run it in full.
(Efficiency reflection goes to the global session log — step 4, not a project
file.) In addition to the shared routing:

- **Accomplished work and files modified** → nowhere: commit messages and git
  history already record these.
- If a `~/.claude/docs/` file needs updating, flag it and ask before editing.

Sharpen the `#debt-scan` for session close — "nothing comes to mind" is not a
pass; look at what actually changed. Classify each finding by when to act, not
by severity:

- **Block now** — leaves the work broken or wrong; fix before closing.
- **Fix before closing** — cleanup that should land as part of this wrap-up.
- **Later task** — legitimate follow-up; add it to `tasks.md` this turn, not
  from memory afterward.
- **Accept** — not worth fixing; drop it, noting the reason only if it isn't
  obvious.

**Structure scan**: for the areas this session changed, evaluate how easy the
file structure is for an agent to work in — for the next likely edit there, how
much must it read, infer, edit, and validate, and how much is hidden. Where the
structure makes that needlessly hard, propose a structural change. Route
findings by the same timing axis as the debt scan.

Don't stop at writing the `Open question:` note down — surface it in chat too.
The user may not expect a fork to still be open, or may want to resolve it now
rather than leave it queued for whoever picks up the task next.

## 4. Reflection and session log

Reflect adversarially: assume meaningful inefficiencies occurred unless evidence
suggests otherwise, and prioritize identifying avoidable waste over highlighting
accomplishments. Cover:

- _Token efficiency_: run
  `~/.claude/hooks/session_tokens.py --print --session-id <id>` for the
  session's token counts so far (provisional — the SessionEnd hook writes the
  final figures). The id is the UUID segment of the scratchpad directory path in
  the system prompt; if it can't be determined, omit the flag — `--print` then
  guesses by newest transcript and warns when concurrent sessions make the guess
  ambiguous. Run it and any other gathering command bare: a redirect to an
  out-of-workspace path (`2>/dev/null`, `>`) trips Claude Code's write-scope
  gate and forces a permission prompt even when the command itself is
  allowlisted. Then diagnose the session's main cost drivers from observable
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
  which actively shaped the session, were violated, or loaded without earning
  their tokens. Hunt the hardest case actively: a rule that should have fired
  but was silently dropped under context pressure. Only the live session shows
  it, and it leaves no citation, so a drop not recorded here is invisible to
  distillation later. One session is citation data, not a verdict: demotion and
  removal decisions belong to distillation across many sessions.
- _Config size_: spot-check the cost side of loaded context — `wc -l` on
  always-loaded files, flagging outliers. When something looks bloated, suggest
  the user run `/context` (per-feature context breakdown) and `/usage`
  (per-skill/subagent/MCP cost attribution) for an authoritative breakdown — a
  manual deep-dive, not a recorded signal.

In chat, give only each finding's conclusion — what the user might act on or
correct. Its diagnosis and mechanism are the narrative behind that conclusion;
they belong in the log entry, not chat. This split holds even when the user has
asked for analysis directly in the conversation — a user question is not an
exception. Write to the log first, then surface the conclusion in chat. Append
an entry to `~/.claude/logs/sessions.md` (create the file if missing):

- Heading: date, project, and session type (coding / debug / refactor / planning
  / explore), followed by a scope line of countable facts — e.g.
  `4 files modified · 2 correction turns · 11 file reads` — then, on its own
  line, the session marker `--print` reported (`<!-- session: <id> -->`). Scope
  facts are events counted from the conversation. Never write token figures into
  the entry: the SessionEnd hook appends the final `tokens:` line at the marker
  after the session ends.
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

To append without a prompt, pipe the entry into
`~/.claude/scripts/append-session-log.py` via a heredoc:

```bash
~/.claude/scripts/append-session-log.py <<'EOF'
…entry…
EOF
```

The script is allowlisted and does the write internally, so it never prompts and
needs no prior read — a raw `cat >>` redirect would cost a permission prompt,
and `Edit` an extra read call first.

A mechanism that generalizes beyond this session belongs in memory or the
relevant rules file — handle that in step 3's memory routing.

Run `~/.claude/scripts/distillation_backlog.py` for the count of reflection
entries since the log's last distillation marker — the entries distillation
consumes (stats-only entries, reported separately, carry none). If it reports
~10 or more reflection entries, suggest running the distill skill — the
suggestion only, not the case for it.

## 5. Pending commits

If in a git repo with uncommitted changes, attempt the commit directly for the
active project — this overrides the harness's built-in
commit-only-when-the-user-asks default, which targets mid-session impulses;
session end is the expected commit point. Exception: when the pending diff is a
durable chunk that has not been through the ownership review, offer
`/ownership-walkthrough` instead of committing directly. The permission mode
gates the commit: silent in auto mode, a prompt in default mode. Never commit
another repo (e.g. dotfiles) this way — surface those changes for the user to
handle.

## 6. Reviewer session

If production code was written, offer:

> "Consider a reviewer session: open a fresh session with the relevant files in
> context and run `/code-review`."

## 7. Clear, compact, or continue

Close with a genuine judgment on what to do with this session next. Weigh what
is in context now, what the next task needs, and the cheapest path to it:

- **Clear** when the next task is unrelated and nothing needs to carry forward —
  eliminates re-ingestion cost entirely.
- **Compact** only when the next task genuinely needs live context from this
  session (mid-task state, open decisions, active debugging). Compaction defers
  re-ingestion cost to the next turn; it does not eliminate it.
- **Continue** only when context is genuinely small and the next task is a
  direct extension.

Clear is the default after a wrap. Say nothing when clearing is right; surface a
recommendation only when compact or continue is the better move, with the reason
it beats clearing.
