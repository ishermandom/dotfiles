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

### Why proofreading brackets the correctness loop

Proofreading runs once before the correctness rounds and then loops after them,
rather than riding along in every round. Each end earns its place differently.
The opening pass is there so the correctness rounds read prose that has already
been cleaned up, rather than spending their attention on wording. The closing
rounds are there because correctness fixes rewrite comments, docstrings, and
documentation, so the prose the opening pass cleaned is no longer the prose that
ships.

Running the check in the middle as well would cost a cold agent per round to
rewrite prose that the next round's correctness fixes are about to overwrite —
churn, paid for repeatedly. Only the closing rounds see prose that has stopped
moving, so only they can converge.

### Why correctness rounds end with an inline follow-through

A convergence run took eighteen cold rounds. Most of them reported damage from
an earlier round's fixes rather than defects in the work under review — an
incomplete fix, two fixes pulling against each other, fix code that missed a
convention. Cold rounds are what this skill spends, so a loop that burns them
rediscovering its own fix damage runs several times longer than the work needs.

Correcting that damage is the one job independence does not help with. The cold
pass earns its cost by reading work it did not write; a session tracing what its
own fix implies wants the opposite — the context that says what changed and why.
So the round hands each job to the reader suited to it, and the inline step is
deliberately not cold.

The step runs after the fixes because the fixes are its input. It is not a
second walk through the findings list: findings arrive one at a time and are
fixed one at a time, so the whole is precisely what no one has looked at yet.

What keeps the inline edits honest is the loop itself. Every round's cold pass
covers the full scope, and the loop ends only on a quiet cold round, so nothing
the inline step wrote can ship without at least one cold pass having read it.

The proofreading rounds close without the step; `proofread/notes.md` holds why.

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
`docs/review-passes.md` repeats this skill's scope step, and its weigh and
report steps repeat this skill's own. Reading the file and citing a single
anchor takes only what this skill uses.

### Why `xhigh` rather than `high`

The built-in routes each effort level through a per-model table. Under Opus 5,
`medium` and `high` land on the same cell, whose prompt asks for a single
careful diff pass capped at 15 findings; `xhigh` is the first level that reaches
the ten-angle prompt with a gap-sweep phase. So `high` would have bought nothing
over `medium` on the model this config targets.

That table is internal and version-specific (read from the 2.1.259 binary).
Re-check it if rounds start coming back thin for no visible reason.

### Why the built-in pass withholds `--fix`

Finding and fixing stay separate roles: the cold pass reports, and every fix
lands through this session's judgment.

The built-in pass is genuinely cold, which is the property the round is built on
— the inline follow-through that closes each round is deliberately not. The
built-in resolves its execution mode from two environment variables — one
selecting coordinator mode, one selecting report-findings mode. Either one runs
the review inline; everything else forks. Neither variable is normally set, so
the review runs as a fork — an agent that reads the diff without having watched
it being written. The built-in's instruction to run its finder angles "in THIS
context — do NOT spawn subagents" governs the angles inside that forked agent;
it does not make the review itself inline.

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

Every round costs a cold agent — an `xhigh` review or a proofreading subagent —
plus the session's own follow-through, and both loops run until they go quiet.
That is too expensive to fire on the model's own initiative; `config-review`,
the closest analogue in cost and shape, is user-invoked for the same reason.

## TODOs and follow-ups

### Overlap with the convergence loop in `ownership-walkthrough`

Step 1 of `ownership-walkthrough` specifies its own `/code-review --fix`
convergence loop, with effort scaled to risk rather than fixed. The two loops
are specified separately and will drift. Unification is deferred and tracked in
the dotfiles `tasks.md`, next to two queued entries that aim a similar prose
check at config files.
