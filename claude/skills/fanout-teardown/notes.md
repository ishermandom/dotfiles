# Fanout teardown skill notes

Maintainer rationale for the `fanout-teardown` skill. The `fanout` skill's
`notes.md` covers the launch side.

- **Teardown runs inside the worktree session**: `wrap-session` reflects on the
  session it is invoked from, so a teardown driven from the main checkout would
  wrap the wrong session entirely. Everything else in the sequence could run
  from either side; wrap is what pins it.

- **Wrap comes before landing**: the debt scan routinely queues follow-up tasks,
  and a wrap run after landing would leave those sitting on a dead branch. Order
  also gives the user one decision point — step 3 — instead of discovering new
  work after `main` has already moved.

- **No review step**: `CLAUDE.md #review-axis` asks for user review before push,
  not for a particular skill, and an agent flags a durable chunk needing
  `/ownership-walkthrough` the same way it would in any session. A review step
  here would restate a rule that already fires.

- **The branch outlives its worktree**: `git worktree remove` leaves
  `worktree-<slug>` behind, so the branch needs deleting on its own. Landing has
  already fast-forwarded `main` to that tip by then.

- **Exiting is what unlocks**: Claude Code locks each worktree to its session,
  recording the session pid as the lock reason. `git worktree remove` fails
  against a live lock (`cannot remove a locked working tree`), so the session
  holding it has to exit rather than the removal being forced.

- **`tasks.md` conflicts are expected, not exceptional**: every fanned-out
  branch edits the tracker, so the second and later landings conflict there by
  construction. That is what the rebase step buys — the conflicts arrive in the
  worktree, with the work still in context, rather than part-way through a land.
