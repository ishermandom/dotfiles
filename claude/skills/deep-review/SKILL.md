---
description: >-
  Review to convergence, two passes per round: the built-in /code-review at
  xhigh, plus the cognitive-load proofreading pass `/proofread` defines. Fix
  what both report, and repeat until a round comes back quiet.
disable-model-invocation: true
---

Each round runs two passes: the built-in `/code-review`, and the proofreading
pass `/proofread` defines. Both report and neither edits — this session applies
every fix, and the rounds repeat until one comes back quiet. Work through the
steps in order.

## 1. Settle the scope

Settle the scope as `~/.claude/docs/review-passes.md` #scope specifies.

## 2. Launch the proofreading pass

Launch the pass as `~/.claude/skills/proofread/SKILL.md` #launch specifies, in
the same turn as the built-in pass (step 3) so the two run concurrently. Neither
pass edits anything, so they cannot collide. Collect both reports before fixing
anything.

## 3. Run the built-in pass

Run `/code-review xhigh` over the scope. Never pass `--fix`: finding and fixing
stay separate roles, and every fix lands together at step 4.

## 4. Pool the findings and fix

Fix both passes' findings together, weighing each as `review-passes.md` #weigh
specifies.

## 5. Repeat to convergence

When a round surfaces findings, run another round after its fixes land. Stop
only when a round comes back without any actionable findings. Each round reviews
the full current scope, never just what changed since the prior round.

Carry between rounds: what earlier rounds fixed, and a ledger of accepted
decisions that neither pass may re-flag. Aim extra scrutiny at the fixes the
previous round made — new fixes are where new defects concentrate.

## 6. Report

Report as `review-passes.md` #report specifies, and add how many rounds the loop
took to go quiet.
