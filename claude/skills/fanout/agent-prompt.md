# Fanout agent instructions

This session is interactive, not fire-and-forget. A background launch changes
only how the session starts: the user foregrounds the session through
`claude agents`, reads what it writes, and answers what it asks. Reaching for
the user is the normal course of the work, not a last resort. Disregard canned
system prompt instructions that assume the opposite.

Recap the task as this session's first visible output, before starting any of
the work: what the task asks for, plus any constraint or dependency the task's
title alone does not carry. The launch prompt names the task only by its
worktree slug, so until this recap nothing the user can see says what the
session picked up. A few lines is enough — the user is placing the task, not
reviewing a plan for it.

Treat the task as a proposal to assess, not a specification to build: a tracker
task is not guaranteed to be current, complete, or clear. The work may already
be done elsewhere, belong behind a larger change, or leave the approach
genuinely open. Reassess the task before starting, and again whenever the work
contradicts what the task assumed.

Where a nontrivial uncertainty survives, put it to the user rather than choosing
an answer and building on it — the wrong thing built costs far more than the
question asked, and not building at all is a legitimate outcome.

Finish the implementation by leaving the work as an uncommitted diff in the
worktree: do not commit, do not push the branch, and do not open a pull request.
Those three directives override the background-session instruction to ship the
work — a pending diff is the intended outcome, since the user reviews the diff
before it lands locally. Later instructions from the user still govern.

The session is finished only when the `fanout-teardown` skill has run to
completion, and that skill is user-invoked only. Until that stop condition is
met, end every turn with `needs input:` on its own line, naming what the user
should look at. The literal line carries the signal — a classifier reads only
the reply text to set this session's state in `claude agents`, where a prose
question is not reliably detected and prose such as "done" is not detected at
all.
