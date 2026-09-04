---
description: >-
  Perform a thorough automated code review, as a precursor to human review.
disable-model-invocation: true
---

Between settling the scope and reporting, three phases run in order: one
proofreading pass, then two loops — correctness rounds, then proofreading
rounds. Each loop runs until a round comes back quiet. Proofreading sits at both
ends and never in the middle: the opening pass hands the correctness rounds
clean prose, and holding the remaining proofreading until the end keeps
documentation from churning while correctness fixes are still landing.

Every round in this skill shares the same core. A cold pass reports over the
full scope — never just what the previous round changed — and it never edits.
This session weighs the pass's findings as `~/.claude/docs/review-passes.md`
#weigh specifies, then applies the fixes. Run another round once the fixes land,
and stop only when a round comes back with nothing actionable. Carry between
rounds what earlier rounds fixed, plus a ledger of settled decisions no later
pass may re-flag.

Work through the steps in order.

## 1. Settle the scope

Settle the scope as `~/.claude/docs/review-passes.md` #scope specifies.

## 2. Proofread once {#opening-pass}

Launch the proofreading pass as `~/.claude/skills/proofread/SKILL.md` #launch
specifies — only that section applies here, since this skill covers scoping,
weighing, and reporting around that launch. Run a single round and stop there;
proofreading loops at #closing-rounds, once correctness has stopped rewriting
the prose.

## 3. Correctness rounds, to convergence

For each round, run a cold pass and then an inline follow-through.

The cold pass is `/code-review xhigh` over the scope. Never pass `--fix`:
finding and fixing stay separate roles, so every fix lands through this
session's judgment rather than a cold agent's.

Once the round's fixes have landed, self-review them inline. Judge the change as
a whole rather than re-reading the findings one at a time; a fix that is right
on its own can still leave the surrounding work inconsistent. Use judgment about
what to follow through on. Some examples: extending a fix, reworking the
surrounding code, or applying a style rule.

Never skip the follow-through on the grounds that the next round would catch the
same thing. Cold rounds are expensive, whereas inline self-review is relatively
cheap.

## 4. Proofreading rounds, to convergence {#closing-rounds}

The cold pass is the proofreading pass, launched exactly as #opening-pass
specifies. These rounds close without an inline follow-through — a rewritten
sentence rarely obliges a change anywhere else.

## 5. Report

Report as `review-passes.md` #report specifies, and add how many rounds each
loop took to go quiet.
