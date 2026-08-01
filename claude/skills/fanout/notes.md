# Fanout skill notes

Maintainer rationale for the `fanout` skill.

- **The launch adds one override and no tool restrictions**: agents are
  otherwise meant to behave as hand-started sessions, so the launch passes
  nothing further — `CLAUDE.md #interaction-style` already covers asking when
  blocked, and `CLAUDE.md #review-axis` covers review. Committing is the one
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

- **No status machinery in the skill**: Claude Code's own background-agent view
  already reports each session's state, setting `waiting` plus a `waitingFor`
  reason whenever a dialog is open — so an `AskUserQuestion` call surfaces there
  without the skill polling or mirroring anything.

- **Fanout width is bounded by file clusters, not by task count**: tracker tasks
  tend to cluster on the same files, and a fanout wider than those clusters just
  moves the conflict from the worktrees to the landing. The user's review
  attention is the tighter limit in practice, since finished branches queue for
  it serially.

- **`.claude/worktrees/` needs a gitignore entry**: a worktree directory shows
  up as untracked in the repo that hosts it, which would otherwise make the
  step-2 base check report a gap for every worktree left over from an earlier
  run.
