---
description:
  Distill recurring patterns from the session log into durable rules and docs.
  Run when wrap-session suggests it, or on demand.
---

Work through each step in order.

## 1. Scope

Read `~/.claude/logs/sessions.md`. Locate the last distillation marker; the
entries after it are this run's input. If no marker exists, read all entries. If
fewer than ~5 entries are in scope, tell the user the input is thin and confirm
before continuing.

## 2. Find patterns

A single occurrence is noise; two or more across sessions is a pattern. Look
for:

- **Recurring inefficiency sources or corrections** — candidates for a new rule,
  a doc note, or a hook.
- **Repeated Adjustments proposals** — the same behavioral fix proposed in two
  sessions is strong evidence it belongs in durable guidance.
- **Rule adherence**: rules that repeatedly shaped sessions are working — leave
  them. Rules the log shows repeatedly violated or silently dropped
  (wrap-session records both from the live session) are graduation candidates —
  harden a persistent violator gradually via the thin-slice trial: it lives in
  CLAUDE.md first and graduates to a hook only after 3–5 sessions show it won't
  hold there. Rules never cited across many sessions are candidates for demotion
  to an on-demand doc or removal. For the systematic citation tally across the
  whole config, remind the user to run `/config-review` — its dead-rule angle
  audits this same log plus the permission-prompts log, and only the user can
  invoke it.
- **Config-size complaints**: when two or more in-scope entries flag the
  config's size or always-loaded weight, escalate — make "run `/config-review`
  to trim dead weight" one of the step 4 proposal items, not just a mention.

## 3. Review pending hypotheses

The **Pending evaluations** section below lists open uncertainties — questions
parked until enough usage accumulates to answer them. Each entry is unresolved
by design; do not read its framing as a conclusion. For each entry, check the
in-scope log entries for evidence that answers the question. When the evidence
is sufficient, fold the answer into the step 4 proposal — act on it (a rule,
doc, or hook) or set it aside — and remove the entry from the list. Leave
unanswered entries in place. When this run surfaces a new open uncertainty, add
it as an entry.

## 4. Propose

Present a numbered proposal in chat — at most five items, highest leverage
first. For each item: the change (add / sharpen / demote / remove, and where —
CLAUDE.md, `rules/*.md`, `docs/`, or a hook), the evidence (which log entries),
and the expected effect. Gather decisions via `AskUserQuestion`.

Before adding any rule, apply the checks in the Claude rules style guide
(`~/.claude/rules/claude-rules-style.md`) — grounding, recognizability, scope,
necessity.

## 5. Apply and mark

Apply the approved changes. Dereference symlinks first: files under `~/.claude/`
resolve into the dotfiles repo (`readlink -f <path>`).

Append a marker entry to the session log:

```markdown
## <date> — distillation

Reviewed <N> entries; applied: <one line>; declined: <one line>.
```

Remind the user to commit the dotfiles changes.

## Pending evaluations

Open uncertainties awaiting enough usage to answer — none is a settled
conclusion. Each entry states the **Question**, then **Measure** (the evidence
that answers it) and the action on each outcome. Step 3 reviews these against
the in-scope log; trim entries as they are answered.

### Hook-output context cost

**Question:** does large hook output crowd the context window often enough to
warrant a guard that inlines a short preview and routes the full output to a
file (naming that file's path in the preview)? **Measure:** whether log entries
show hook dumps large or frequent enough to bury later content. If yes, build
the guard; if large output stays rare, drop the idea.

### Task complexity routing

**Question:** do explicit planning tiers by task size (1–2 files → direct; 3–5 →
design phase; 6+ → full plan) add value, or does the conversational planning
flow already handle sizing without the ceremony? **Measure:** sessions across a
range of task sizes — whether mis-sized planning (too heavy or too light)
recurs. If tiers help, define them; if the flow handles it, drop the idea.

### Mechanical tool trace for rule adherence

**Question:** is the narrative rule-adherence signal in the session log
(`wrap-session`'s Rules section) insufficient often enough — missing or
rationalizing rules that were silently dropped — to justify a mechanical
per-call tool trace as a distillation input? **Measure:** distill runs where a
violation surfaces from tool-call evidence the narrative had missed or
downplayed. If that recurs, build the trace — a digested `PostToolUse` JSONL, or
teach distill to parse the session transcript (which already records every tool
call); if the narrative suffices, drop the idea.
