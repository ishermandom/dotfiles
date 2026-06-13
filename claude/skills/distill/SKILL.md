---
description:
  Distill recurring patterns from the session log into durable rules and docs.
  Run when wrap-session suggests it, or on demand.
allowed-tools: Read, Edit, Write, Bash
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
- **Rule citations**: rules that repeatedly shaped sessions are working — leave
  them. Rules repeatedly violated are candidates for sharpening or for
  graduation to a hook. Rules never cited across many sessions are candidates
  for demotion to an on-demand doc or removal.

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

### Size-check mechanism

**Question:** for the `wrap-session` size tooling, are line-count tripwires or
`/context` shares the more effective check? **Measure:** sessions that exercise
both enough to compare. Keep the winner and retire the other.

### Task complexity routing

**Question:** do explicit planning tiers by task size (1–2 files → direct; 3–5 →
design phase; 6+ → full plan) add value, or does the conversational planning
flow already handle sizing without the ceremony? **Measure:** sessions across a
range of task sizes — whether mis-sized planning (too heavy or too light)
recurs. If tiers help, define them; if the flow handles it, drop the idea.
