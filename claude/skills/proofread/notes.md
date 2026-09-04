# Maintainer notes: proofread

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context.

## Design decisions

### Why the agent is cold, read-only, and single

Sympathetic review under-finds: a session that just wrote a passage reads past
its own clunky phrasing. Read-only keeps finding and fixing apart, so every
rewrite passes through the session's own judgment before landing rather than
arriving already applied.

One agent rather than a fan-out. Proofreading does not gain from independent
angles the way bug-hunting does — a second reader over the same prose mostly
re-finds what the first one did, and returns overlapping rewrites of the same
sentences for the session to reconcile. Splitting the work by file would also
cost each agent the surrounding context the check tells it to read.

### What the check leaves to the agent's judgment

The check names recurring shapes of high cognitive load and stops there.
Mechanical errors — typos, broken markdown, a reference that no longer resolves
— are deliberately unlisted: a capable agent flags them without being asked, and
enumerating them invites exactly the checklist mindset the check steers the
agent away from. The same reasoning covers anything else absent from the list.

### Why no follow-through step on the fixes {#no-follow-through}

`deep-review` closes each of its correctness rounds by reading that round's
fixes as a single change and self-reviewing it, because a correctness fix
routinely reaches beyond the spot where the finding was reported. No
proofreading round takes that step, here or inside `deep-review`. Proofreading
fixes are far more isolated — a rewritten sentence rarely obliges a change
anywhere else — so the step would mostly find nothing to do.

### Why the skill is user-invoked only

Starting a review is the user's call — CLAUDE.md #land-go-ahead has Claude
suggest one rather than initiate it. A single pass is cheap enough that cost
alone would not settle the question. What settles it is who gets to start a
review.

### Why the check stays here and the shared steps do not

What a pass covers, what becomes of its findings, and how they are reported are
the same whichever check runs, so those steps live in `docs/review-passes.md`
where every skill running a pass can follow one copy. The check distinguishes
this skill from any other pass, so it stays here.
