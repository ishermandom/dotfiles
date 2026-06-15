# Maintainer notes: spec

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context.

## TODOs and follow-ups

### A parallel-scout mode for genuinely-open design questions

The interview (step 2) gathers requirements through one interactive
`AskUserQuestion` thread. It assumes the option space is known well enough to
enumerate choices. When a design question is genuinely open — the viable
approaches aren't yet known — an `/angles`-style pass could help: spawn
independent subagent scouts to generate distinct approaches, collapse duplicate
angles, and surface a structured option table before the interview narrows.

Deferred: the niche is narrow and overlaps the existing interview and
`AskUserQuestion`, so it earns its cost only when the option space is truly
unknown — not the common case. If adopted, it honors the
present-research-before-deciding rule: full scout findings (or a faithful
digest) land in chat before the pick, not just the table. The broader hook —
underusing subagents across workflows generally — is tracked separately and
isn't specific to this skill.
