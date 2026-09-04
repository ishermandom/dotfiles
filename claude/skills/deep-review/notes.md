# Maintainer notes: deep-review

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context.

## Design decisions

### Skill name

"deep" tab-completes uniquely across the installed skills. "review" does not —
it is ambiguous among `code-review`, `config-review`, and `security-review` — so
only one of the two words is a usable prefix. The two-word name was chosen
deliberately over a collision-free single word such as "converge", which would
tab-complete from its own first letters but says nothing about what the skill
does.

### Why the proofreading check runs as its own pass

The built-in `/code-review` has no extension point for a custom check. Its
argument parser recognizes four flags — `--comment`, `--fix`, `--post`,
`--no-post` — plus an optional leading effort level, and treats every remaining
token as the review target. Instruction text appended to the invocation would be
read as a path, branch, or pull request number rather than as an added check
(verified against the 2.1.259 binary).

Beyond the missing extension point, the built-in's own prompt pushes against
this check. Its lower-effort variants tell the reviewer to prefer real failure
modes over style, and every variant caps its findings — both at odds with
proofreading that reports every issue it finds.

### Why this skill reads `/proofread` rather than invoking it

`proofread/SKILL.md` #launch holds what this skill needs from that one: the
check, and how to launch it. Everything else about the pass comes from
`docs/review-passes.md` directly.

Invoking `/proofread` would load its framing of the check too — its pointer to
`docs/review-passes.md` repeats step 1, and its weigh and report steps repeat
steps 4 and 6. Reading the file and citing a single anchor takes only what this
skill uses.

### Why `xhigh` rather than `high`

The built-in routes each effort level through a per-model table. Under Opus 5,
`medium` and `high` land on the same cell, whose prompt asks for a single
careful diff pass capped at 15 findings; `xhigh` is the first level that reaches
the ten-angle prompt with a gap-sweep phase. So `high` would have bought nothing
over `medium` on the model this config targets.

That table is internal and version-specific (read from the 2.1.259 binary).
Re-check it if rounds start coming back thin for no visible reason.

### Why the built-in pass withholds `--fix`

Finding and fixing stay separate roles, and both passes report before anything
is edited. Withholding `--fix` also buys parallelism: with `--fix`, the built-in
would be rewriting files while the proofreading agent was still reading them, so
the two passes would have to be serialized.

Both passes are cold, which is the property the loop is built on. The built-in
resolves its execution mode from two environment variables — one selecting
coordinator mode, one selecting report-findings mode. Either one runs the review
inline; everything else forks. Neither variable is normally set, so the review
runs as a fork — an agent that reads the diff without having watched it being
written. The built-in's instruction to run its finder angles "in THIS context —
do NOT spawn subagents" governs the angles inside that forked agent; it does not
make the review itself inline.

Withholding `--fix` matters more because of the fork, not less: with `--fix` the
cold agent both finds and fixes, which puts the edits in the context least
equipped to weigh them against the surrounding work.

### Why nothing re-reports finding outcomes

The built-in carries an instruction to call `ReportFindings` a second time, with
an outcome per finding, whenever reported findings are fixed later in the
session. That instruction is attached conditionally, gated on the same
report-findings environment variable that forces the review inline. So it never
reaches a forked review: a forked review always reports its findings as text,
and a step telling this skill to re-report outcomes would be dead in every real
run.

### Why the skill is user-invoked only

A round costs an `xhigh` review plus a cold proofreading subagent, and the skill
runs rounds until they go quiet. That is too expensive to fire on the model's
own initiative; `config-review`, the closest analogue in cost and shape, is
user-invoked for the same reason.

## TODOs and follow-ups

### Overlap with the convergence loop in `ownership-walkthrough`

Step 1 of `ownership-walkthrough` specifies its own `/code-review --fix`
convergence loop, with effort scaled to risk rather than fixed. The two loops
are specified separately and will drift. Unification is deferred and tracked in
the dotfiles `tasks.md`, next to two queued entries that aim a similar prose
check at config files.
