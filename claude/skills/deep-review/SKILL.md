---
description: >-
  Review to convergence with two passes per round — the built-in /code-review at
  xhigh, plus a cold-subagent proofreading pass for cognitive load — fixing what
  both report and repeating until a round comes back quiet.
disable-model-invocation: true
---

Each round runs two passes: the built-in `/code-review`, and a proofreading pass
the built-in does not cover. Both report and neither edits — this session
applies every fix, and the rounds repeat until one comes back quiet. Work
through the steps in order.

## 1. Settle the scope

The scope is everything not yet reviewed — usually the pending diff, plus any
commits made ahead of the review, whether or not they have been pushed. Anything
the user names at invocation overrides that and passes through to `/code-review`
as its target.

## 2. Launch the proofreading pass

Launch one cold subagent over the scope — a fresh agent, never a fork, since a
fork inherits this session's context along with the blind spots this pass exists
to catch.

Launch it in the same turn as the built-in pass so the two run concurrently.
Neither pass edits anything, so they cannot collide. Collect both reports before
fixing anything.

Give the agent the check below verbatim, the files and changed line ranges in
scope, and any ledger of accepted decisions carried from earlier rounds.

```text
Proofread the changed lines through a single lens: cognitive load. How easily
does a cold reader understand this on the first read, and how much do
they have to hold in mind while reading? Read whatever surrounding context
bears on that question.

Prose carries most of that load — documentation, comments, docstrings, error
and log messages, user-facing strings — so focus there. The same lens reaches
code wherever reading it is the cost.

Judge for yourself what raises the load. These are some of the recurring shapes
it takes, not an exhaustive list:

- clunky phrasing that has to be read twice
- a run-on sentence that would be easier to follow if split into simpler ones
- wording that costs more to decode than it saves — jargon, an acronym, an
  abstract term standing in for a concrete instance
- an ordering that leaves something unexplained while the reader needs it

Treat the style rules already in context as part of the lens: CLAUDE.md,
including its guidance on pronouns, and any rules file matching the files
under review. Where they disagree with anything here, they win.

For every finding, propose a concrete edit or fix.

Report every finding — there is no cap. The restraint is about kind, not
count: every finding names what the reader stumbles on, and a rewrite trading
one phrasing for another equally good one is churn rather than a finding.

Work read-only: report findings, change nothing.
```

## 3. Run the built-in pass

Run `/code-review xhigh` over the scope. Never pass `--fix`: finding and fixing
stay separate roles, and every fix lands together at step 4.

## 4. Pool the findings and fix

Fix both passes' findings here, in this session. Every finding arrives as a
proposal from a context that saw less than this session does, so evaluate each
one on its merits and then accept it, refine it, or reject it. Carry every one
of those decisions into the step 6 report.

## 5. Repeat to convergence

When a round surfaces findings, run another round after its fixes land. Stop
only when a round comes back without any actionable findings. Each round reviews
the full current scope, never just the prior round's delta.

Carry between rounds: what earlier rounds fixed, a ledger of accepted decisions
that neither pass may re-flag, and directed scrutiny at the previous round's fix
code — new fixes are where new defects concentrate.

## 6. Report

Give every finding its resolution — accepted, refined, or rejected — with the
reasoning behind anything not applied as proposed, and say how many rounds it
took to go quiet. When listing all findings would be overwhelming, summarize as
needed. However, always individually list out all high-severity findings. Stop
there: this skill reviews and fixes, and does not commit.
