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

- **No review step**: `CLAUDE.md #review-gate` asks for user review before
  landing, not for a particular skill, and an agent flags a durable chunk
  needing `/ownership-walkthrough` the same way it would in any session. A
  review step here would restate a rule that already fires.

- **The branch outlives its worktree**: `git worktree remove` leaves
  `worktree-<slug>` behind, so the branch needs deleting on its own. Landing has
  already fast-forwarded `main` to that tip by then.

- **Exiting is what unlocks**: Claude Code locks each worktree to its session,
  recording the session pid as the lock reason. `git worktree remove` fails
  against a live lock (`cannot remove a locked working tree`), so the session
  holding it has to exit rather than the removal being forced.

- **The session stops itself**: `claude stop` works from inside the session it
  names (verified 2026-08-01), so the final step needs no hand-off to the user.
  Reverting to a printed command is the tempting mistake, on the reasoning that
  a running session cannot issue its own stop. A session can.

- **The id comes from the environment**: `CLAUDE_CODE_SESSION_ID` holds the
  session's own id, whose leading segment is the short form `claude stop` takes.
  A `claude agents` lookup would also reach it, but concurrent fanout sessions
  are told apart there only by the worktree slug inside their launch prompt, and
  stopping a sibling interrupts live work.

- **`tasks.md` conflicts are expected, not exceptional**: every fanned-out
  branch edits the tracker, so the second and later landings conflict there by
  construction. That is what the rebase step buys — the conflicts arrive in the
  worktree, with the work still in context, rather than part-way through a land.
