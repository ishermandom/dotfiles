# Fanout skill notes

Maintainer rationale for the `fanout` skill.

- **No appended system prompt and no tool restrictions**: agents are meant to
  behave exactly as hand-started sessions, and CLAUDE.md already carries the
  rules a fanout would otherwise restate — the dotfiles commit rule keeps agents
  from committing, `CLAUDE.md #interaction-style` covers asking when blocked,
  and `CLAUDE.md #review-axis` covers review. Adding `--append-system-prompt` or
  `--disallowed-tools` would duplicate rules that already fire, which drifts.

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
