---
description: >-
  Proofread the changed lines for cognitive load: a cold subagent reports what a
  first-time reader stumbles on, and this session applies the fixes. One pass —
  `/deep-review` runs the same pass to convergence beside `/code-review`.
disable-model-invocation: true
---

A cold subagent reads the changed lines the way a first-time reader would and
reports what costs them effort. It never edits — this session weighs every
finding and applies the fixes.

Read `~/.claude/docs/review-passes.md` and follow it: it settles the scope
(#scope), and covers what to do with the findings once they arrive (#weigh) and
how to report them (#report). This skill supplies the one part it does not — the
check the agent runs.

## Launch the pass {#launch}

Launch one cold subagent over the scope — a fresh agent, never a fork, since a
fork inherits this session's context along with the blind spots this pass exists
to catch.

Give the agent the check below verbatim, the files and changed line ranges in
scope, and any ledger of accepted decisions the pass may not re-flag.

```text
Proofread the changed lines through a single lens: cognitive load. How easily
does a cold reader understand the content on the first read, and how much do
they have to hold in mind while reading? Read whatever surrounding context
bears on that question.

Prose carries most of that load — documentation, comments, docstrings, error
and log messages, user-facing strings — so focus there. The same lens applies
to code wherever the difficulty is in reading it.

Judge for yourself what raises the load. These are some of the recurring shapes
it takes, not an exhaustive list:

- clunky phrasing that has to be read twice
- a run-on sentence that would be easier to follow if split into simpler ones
- wording that costs more to decode than it saves — jargon, an acronym, an
  abstract term standing in for a concrete instance
- an ordering that leaves something unexplained at the point the reader needs
  it

Treat the style rules already in context as part of the lens: CLAUDE.md,
including its guidance on pronouns, and any rules file matching the files
under review. Where those rules disagree with anything here, the rules win.

For every finding, propose a concrete edit or fix.

Report every finding — there is no cap. Restraint applies to the kind of
finding, not the number: every finding names what the reader stumbles on, and
a rewrite trading one phrasing for another equally good one is churn rather
than a finding.

Work read-only: report findings, change nothing.
```
