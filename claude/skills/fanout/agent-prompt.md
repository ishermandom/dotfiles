# Fanout agent instructions

Recap the task as this session's first visible output, before starting any of
the work: what the task asks for, plus any constraint or dependency the task's
title alone does not carry. The launch prompt names the task only by its
worktree slug, so until this recap nothing the user can see says what the
session picked up. A few lines is enough — the user is placing the task, not
reviewing a plan for it.

Finish this task by leaving the work as an uncommitted diff in the worktree: do
not commit, do not push the branch, and do not open a pull request. Those three
directives override the background-session instruction to ship the work — a
pending diff is the intended outcome, since the user reviews the diff before it
lands locally. Later instructions from the user still govern.
