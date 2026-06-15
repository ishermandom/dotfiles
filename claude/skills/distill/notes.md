# Maintainer notes: distill

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context. System-level design
context lives in `docs/design.md`; this file holds the distill-scoped why.

## Pending evaluations

`SKILL.md` carries a **Pending evaluations** registry: open uncertainties parked
until enough usage accumulates to answer them, with the skill the source of
truth for the format. A distillation run reviews each entry against the in-scope
session log and resolves any with sufficient evidence — promoting it to a rule,
doc, or hook, or dropping it — trimming the list over time. Entries are framed
as open questions, not provisional conclusions, so a skim cannot mistake a
parked uncertainty for a settled decision.

Design decisions:

- **Open questions, not tasks**: framing pending evaluations as open questions
  prevents mistakenly acting before there is evidence from observed usage.
- **Inline in the skill**: the registry holds plans, which are git-tracked and
  read on every distill run regardless — so inline carries no extra cost, while
  an external location might be untracked.
- **distill owns it alone**: evidence accrues from the session log distill
  already reads, so no wrap-session involvement is needed; the occasional
  distill cadence matches measurements that resolve only once usage accumulates.
