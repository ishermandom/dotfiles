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

- **The lane never stops itself**: `claude stop` does work from inside the
  session it names (verified 2026-08-01), so "a running session cannot issue its
  own stop" is not the reason stopping is left to the user. The reason is the
  report: the closing text vanishes alongside the stop, and the stopped row
  drops out of the default `claude agents` listing — so nothing the user sees
  says what landed. `fanout/notes.md #state-reporting` covers what the closing
  `result:` line does instead. Step 8 names that marker rather than
  `agent-prompt.md` doing so: a skill can override the prompt's turn-ending
  convention at the moment that convention lapses, so teardown's detail stays in
  teardown.

- **The tracker edit follows the rebase**: every fanned-out branch edits
  `tasks.md`, and merging one of those edits against a stale base is not safely
  mechanical — `fanout/notes.md #tracker-merges` carries the hazard and the
  case. Ordering the edit after the rebase removes the hazard rather than asking
  each lane to resolve it, since the entry is then written against `main`'s
  current tracker. What wrap queued earlier still rides through the rebase, and
  those are additions rather than deletions — the rebase step says whose side
  wins when one collides.
