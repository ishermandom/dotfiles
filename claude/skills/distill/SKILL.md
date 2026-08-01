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

Before adding any rule, apply the checks in the Claude configuration guide
(`~/.claude/rules/claude-configuration.md`) — grounding, recognizability, scope,
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

### Unverified claims stated as fact

**Question:** what mechanism, if any, would stop Claude from stating unchecked
claims with the confidence of checked ones? CLAUDE.md #inference-vs-fact covers
the behavior and was loaded in every session that violated it — roughly thirteen
between 2026-06-18 and 2026-07-30, the most violated rule of that span — so the
gap is in firing, not in wording. **Measure:** read `inference-vs-fact-cases.md`
beside this file before proposing anything. It holds the accumulated cases, the
approaches already rejected, and the sessions where the rule did fire; append
new instances there as they occur. Act only when a candidate survives the
`rules/claude-configuration.md` #writing-a-rule checks — recognizability and
transition-anchoring above all. Drop the question if the pattern stops
recurring.

### Loaded rules dropped while authoring

**Question:** what would make a rule that is loaded, quotable, and directly
applicable fire while Claude is writing, rather than after a review or a user
correction surfaces it? The new-file half of this pattern has a mechanical cause
and is already handled by CLAUDE.md #new-file-rules; what remains is rules
dropped while editing an existing file or writing chat, with the rule in context
throughout. **Measure:** read `rules-not-self-applied-cases.md` beside this file
before proposing anything — it holds the cases and the approaches already
rejected, including two wordings that failed on coverage or cost. Append new
instances there, noting whether each dropped rule was a single directive or
enumerated the constructs it applies to.
