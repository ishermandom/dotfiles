# Maintainer notes: ownership-walkthrough

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context.

## Design decisions

### Skill name

Chosen for collision-free tab completion so that either word ("ownership" or
"walkthrough") completes it. Note that the more natural "review" term is omitted
as it conflicts with the built in "/review" and "/code-review" skills.

### Why step 1 delegates its loop to `deep-review`

One home for the convergence loop, which repeats `/code-review` rounds until one
comes back quiet. Two separate descriptions of it drift apart, and it is the
expensive part of both skills.

`deep-review` is user-invocable only, so step 1 reads its `SKILL.md` and follows
it — the same move `deep-review` makes when it follows `proofread`. Reading the
file sidesteps that restriction; `deep-review/notes.md` #user-invoked-only says
what that costs.

## TODOs and follow-ups

### A spec-compliance stage

The skill reviews two axes: code quality (step 1, the `deep-review` loops) and
ownership (steps 2–5, the risk-labeled attention map). It does not explicitly
check spec compliance — whether the change does what the task asked, as distinct
from whether the code is good or whether the user understands it. A change can
be clean and fully understood yet solve the wrong problem.

Folding a distinct spec-compliance stage in was considered and deferred. In
interactive use — the mode this skill targets — the user watches the work and
reads the actual diff, so a compliance mismatch surfaces organically (step 5
already explains decisions and the alternatives weighed). A separate stage earns
its cost only under autonomous execution, where the user did not watch the work.

If autonomous execution is ever adopted, the natural site is a compliance pass
preceding step 1's code-quality pass — the "compliance first, then quality"
order (the Superpowers two-stage-review pattern).

### Early-use watch items

Two spots remain worth watching for friction while real-change runs are still
few: partitioning the work into logical units (step 2), and following
`deep-review` from within the skill (step 1).
