# Maintainer notes: proofread

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context.

## Design decisions

### Why the agent is cold, read-only, and single

Sympathetic review under-finds: a session that just wrote a passage reads past
its own clunky phrasing. Read-only keeps the two roles apart, so every rewrite
passes through the session's own judgment before landing rather than arriving
already applied.

One agent rather than a fan-out. Proofreading does not gain from independent
angles the way bug-hunting does — a second reader over the same prose mostly
re-finds what the first one did, and returns overlapping rewrites of the same
sentences for the session to reconcile. Splitting the work by file would also
cost each agent the surrounding context the check tells it to read.

### What the check leaves to the agent's judgment

The check names recurring shapes of high cognitive load and stops there.
Mechanical errors — typos, broken markdown, a reference that no longer resolves
— are deliberately unlisted: a capable agent flags them without being asked, and
enumerating them invites exactly the checklist reading the check tells the agent
to avoid. The same reasoning covers anything else absent from the list.

### Why the skill is user-invoked only

Starting a review is the user's call — CLAUDE.md has Claude suggest one and
never initiate it. A single pass is cheap enough that cost alone would not
settle the question; who gets to start it does.

### Why the check stays here and the harness does not {#check-location}

What a pass covers, what becomes of its findings, and how they are reported are
the same whichever check runs, so those steps live in `docs/review-passes.md`
where every skill running a pass can follow one copy. The check is what
distinguishes this skill from any other pass, so it stays here. Splitting it out
further, into a `check.md` beside this file, would leave `SKILL.md` a wrapper
around a file it always reads.
