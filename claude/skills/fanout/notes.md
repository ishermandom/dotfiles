# Fanout skill notes

Maintainer rationale for the `fanout` skill.

- **The launch adds one override and no tool restrictions**: agents are
  otherwise meant to behave as hand-started sessions, so the launch passes
  nothing further — `CLAUDE.md #interaction-style` already covers asking when
  blocked, and `CLAUDE.md #review-gate` covers review. Committing is the one
  place a background session carries its own contrary instructions — commit,
  push the branch, open a pull request — which CLAUDE.md and the local landing
  flow contradict without silencing. Overriding those instructions at launch is
  what keeps each agent from reasoning the clash out alone.

  The override text sits in `agent-prompt.md` rather than inline in the launch
  command, which keeps the command scannable and keeps literal newlines out of a
  shell argument. `--append-system-prompt-file` is undocumented in
  `claude --help` but accepted, and is on the CLI's allowlist of flags persisted
  as a background job's respawn flags — so the override survives a respawn
  rather than evaporating mid-run (verified in CLI 2.1.220).

- **Leaving the work uncommitted risks nothing**: both automatic worktree
  cleanups — the stale-worktree sweep and the job-retention reaper — refuse any
  worktree whose `git status --porcelain` is non-empty, and log the worktree as
  kept. Removal takes a deliberate act: `ExitWorktree`'s remove path, the
  interactive exit dialog, or `git worktree remove` by hand. So a pending diff
  waiting on the user is not a race against cleanup (verified in CLI 2.1.220).

- **The agent creates its own worktree, rather than the skill passing `-w`**:
  fewer moving parts in the skill, and worktree setup is ordinary work an agent
  can do. Note that agent-driven entry does not dodge the `origin/main` base —
  `EnterWorktree` reads the same `worktree.baseRef` setting `claude -w` does, so
  only changing that setting (or branching from local HEAD by hand) moves the
  base.

- **The tracker line doubles as the task's address**: writing `Worktree: <slug>`
  before launching lets the prompt name the task by that line instead of
  restating the task text, so the tracker stays the single copy of what the work
  is. The line's primary job is keeping in-flight state visible — which task is
  running, and where to resume it.

- **The recap is the agent's own output, not a launch-time label**: `--name`
  would put a tidier title in the background-agent listing, but a label the
  launch writes can only repeat what the launch already knew. What the user
  wants from a running session is the task as the agent understood it, so the
  recap belongs in the session's output.

- **State reporting rides on Claude Code's own view, with one prompt-level
  assist**: the background-agent view sets `waiting` plus a `waitingFor` reason
  whenever a dialog is open, so an `AskUserQuestion` call surfaces there without
  the skill polling or mirroring anything. End-of-turn state is weaker — a
  classifier reads only the reply text and infers `working`, `blocked`, `done`,
  or `failed` from the prose, so a turn ending on a question can read as
  finished. `agent-prompt.md` has each agent close with `needs input:` instead,
  which pins the row to `blocked` for as long as the job lives:
  `fanout-teardown` is user-invoked, so no agent can finish its own task, and a
  `done` row would drop out of the default listing once the process exits —
  hiding a worktree that still needs landing. The sibling `failed:` marker stays
  unused for that same reason, `done`, `failed`, and `stopped` being alike
  terminal: an impossible task ends by telling the user so and asking, never by
  reporting failure into a row that then disappears. The marker convention ships
  with the built-in `claude` agent type, which a bare `claude --bg` launch does
  not apply (verified in CLI 2.1.220).

- **Fanout width is bounded by file clusters, not by task count**: tracker tasks
  tend to cluster on the same files, and a fanout wider than those clusters just
  moves the conflict from the worktrees to the landing. The user's review
  attention is the tighter limit in practice, since finished branches queue for
  it serially.

- **`.claude/worktrees/` needs a gitignore entry**: a worktree directory shows
  up as untracked in the repo that hosts it, which would otherwise make the
  step-2 base check report a gap for every worktree left over from an earlier
  run.
