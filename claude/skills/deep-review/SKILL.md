---
description: >-
  Perform a thorough automated code review, as a precursor to human review.
disable-model-invocation: true
---

Three phases, in order: one proofreading pass, then two loops — correctness
rounds, then proofreading rounds — each run until it comes back quiet.
Proofreading sits at both ends and never in the middle: the opening pass hands
the correctness rounds clean prose, and withholding the rest keeps documentation
from churning while correctness is still being fixed.

A round works the same way everywhere in this skill. A cold pass reports over
the full scope — never just what the previous round changed — and never edits;
this session weighs its findings as `~/.claude/docs/review-passes.md` #weigh
specifies and applies the fixes. Run another round once the fixes land, and stop
only when a round comes back with nothing actionable. Carry between rounds what
earlier rounds fixed, plus a ledger of accepted decisions no pass may re-flag.

Work through the steps in order.

## 1. Settle the scope

Settle the scope as `~/.claude/docs/review-passes.md` #scope specifies.

## 2. Proofread once {#opening-pass}

Launch the proofreading pass as `~/.claude/skills/proofread/SKILL.md` #launch
specifies — only that section applies here, since this skill's own steps cover
the scope, weighing, and reporting around it. Run one round on that pass and
stop there — proofreading loops at #closing-rounds, once correctness has stopped
rewriting the prose.

## 3. Correctness rounds, to convergence

For each round, run a cold pass and then an inline follow-through.

The cold pass is `/code-review xhigh` over the scope. Never pass `--fix`:
finding and fixing stay separate roles, so every fix lands through this
session's judgment rather than a cold agent's.

Once the round's fixes have landed, self-review them inline. Judge the change as
a whole rather than re-reading the findings one at a time; a fix that is right
on its own can still leave the surrounding work inconsistent. What that turns up
is a matter of judgment — extending a fix, reworking the surrounding code, and
applying a style rule are some of the shapes it takes, not a checklist to work
through.

Never skip that follow-through as something the next round would catch anyway.
Cold rounds are expensive, whereas inline self-review is relatively cheap.

## 4. Proofreading rounds, to convergence {#closing-rounds}

The cold pass is the proofreading pass, launched exactly as #opening-pass
specifies.

## 5. Report

Report as `review-passes.md` #report specifies, and add how many rounds each
loop took to go quiet.
