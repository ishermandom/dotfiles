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

## 3. Propose

Present a numbered proposal in chat — at most five items, highest leverage
first. For each item: the change (add / sharpen / demote / remove, and where —
CLAUDE.md, `rules/*.md`, `docs/`, or a hook), the evidence (which log entries),
and the expected effect. Gather decisions via `AskUserQuestion`.

Before adding any rule, apply the checks in the Claude rules style guide
(`~/.claude/rules/claude-rules-style.md`) — grounding, recognizability, scope,
necessity.

## 4. Apply and mark

Apply the approved changes. Dereference symlinks first: files under `~/.claude/`
resolve into the dotfiles repo (`readlink -f <path>`).

Append a marker entry to the session log:

```markdown
## <date> — distillation

Reviewed <N> entries; applied: <one line>; declined: <one line>.
```

Remind the user to commit the dotfiles changes.
