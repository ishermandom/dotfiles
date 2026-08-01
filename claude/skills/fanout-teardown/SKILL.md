---
description:
  Conclude one fanned-out task — wrap the session, land its worktree onto main,
  and clear the worktree away. Run from inside the task's own worktree session.
disable-model-invocation: true
---

Conclude a single fanned-out task: settle its work, land it on `main`, and
remove the worktree behind it. Run this from inside the task's own worktree
session — `wrap-session` reflects on whichever session it runs in, so driving
teardown from anywhere else wraps the wrong one. Work the steps in order.

## Steps

1. **Ensure nothing is still pending in the worktree**: `git land` refuses a
   dirty tree, and the steps below add their own commits on top of settled work.
   If there are pending diffs: commit them if the user has granted explicit
   approval; otherwise, pause and confirm next steps with the user.

2. **Run the `wrap-session` skill**: its debt scan is what turns a session's
   loose ends into queued tasks, and running it before landing carries those
   onto `main` in the same pass instead of stranding them on a branch.

3. **Stop here when wrap queued new tasks or flagged debt**: report what it
   surfaced and hand back, leaving the new work for the user to review at their
   own pace. Carry straight on when wrap surfaced nothing. On a later
   invocation, judge from context whether to pick up here or start over — a wrap
   that has gone stale is worth redoing.

4. **Rebase onto `main` before landing**: conflicts then surface here, in the
   worktree, while the work is still in context. A `tasks.md` conflict means
   another lane landed first — an entry missing from `main` was pruned by the
   lane that finished that work. Be careful not to accidentally undo other
   lanes' changes.

5. **Bring the task's tracker entry up to date**: delete its `Worktree:` line,
   and prune or update the task as appropriate. Commit the edit, treating it as
   user-approved — the tracker change belongs in the same landing as the work it
   describes.

6. **Land, then confirm before pushing**: run `git land`, which fast-forwards
   `main` and stops there. Push only if the user has requested a push, or if the
   landed commits are the only unpushed state — otherwise, `main` may carry
   other commits not ready to go out.

7. **Clean up the worktree and its branch**: the session lands back in the main
   checkout with the worktree and its branch removed. Landing already
   fast-forwarded `main` to the branch tip, so deleting the branch loses
   nothing.

8. **Close the background session**: report the outcome, then run
   `claude stop "${CLAUDE_CODE_SESSION_ID%%-*}"`.
