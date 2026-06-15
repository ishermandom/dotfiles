# Maintainer notes: ownership-walkthrough

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context.

## Design decisions

### `allowed-tools` is left unrestricted

The skill's frontmatter sets no `allowed-tools` allowlist: the walkthrough
invokes `/code-review` and `/simplify` as sub-skills and runs git and edits, so
a tight allowlist risks silently breaking the self-review step.

### Skill name

Chosen for collision-free tab completion — the built-in `/review` already exists
— and so that either word ("ownership" or "walkthrough") completes it.

## TODOs and follow-ups

### A spec-compliance stage

The skill reviews two axes: code quality (step 1, `/code-review --fix`) and
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

### First-use validation

The skill has never run on a real production change. On its first use, watch for
friction in two spots: partitioning the diff into logical units (step 2), and
invoking `/code-review --fix` from within the skill (step 1).
