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

- **Open questions, not tasks**: a question like "is large hook output a real
  context problem?" can't be answered by deciding — only by observing usage.
  Parking it as an open evaluation keeps it from being built speculatively or
  lost as a stale backlog item; the build ships only when evidence warrants.
- **Inline in the skill, not a log file**: the registry holds plans, which are
  git-tracked and read on every distill run regardless — so inline carries no
  extra cost, while `~/.claude/logs/` is untracked and append-only, the wrong
  shape for a mutable list.
- **distill owns it alone**: evidence accrues from the session log distill
  already reads, so no wrap-session involvement is needed; the occasional
  distill cadence matches measurements that resolve only once usage accumulates.

Seeded from two deferred measurements that previously lived in a project
`tasks.md`: the hook-output context cost and the wrap-session size-check
mechanism. A later entry parks whether a mechanical per-call tool trace is worth
building for rule-adherence diagnosis — deferred rather than built because the
raw trace already lives in session transcripts and the digest's payoff is
unproven.
