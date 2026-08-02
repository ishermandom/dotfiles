# Fanout skill notes

Maintainer rationale for the `fanout` skill.

- **The launch overrides only where a background session is told otherwise**:
  agents are meant to behave as hand-started sessions, so the launch passes
  nothing beyond that — no tool restrictions, and `CLAUDE.md #review-gate`
  already covers review. Two subjects carry contrary instructions. Committing is
  one: a background session is told to commit, push the branch, and open a pull
  request, which CLAUDE.md and the local landing flow contradict without
  silencing. Asking is the other: the same instructions reserve blocking
  questions for cases where proceeding would be unsafe and call the requested
  scope the deliverable, which together push an agent to build a task it should
  have questioned. Overriding both at launch keeps each agent from reasoning the
  clash out alone. Naming the two is not the whole mechanism — the opening
  paragraph also directs agents to disregard canned instructions that assume a
  non-interactive session, which catches contrary text the pair does not
  anticipate.

  The override text sits in `agent-prompt.md` rather than inline in the launch
  command, which keeps the command scannable and keeps literal newlines out of a
  shell argument. `--append-system-prompt-file` is undocumented in
  `claude --help` but accepted, and is on the CLI's allowlist of flags persisted
  as a background job's respawn flags — so the override survives a respawn
  rather than evaporating mid-run (verified in CLI 2.1.220).

- **The reassessment directive covers the task's premise, not only its
  approach**: the wording that reached the 2026-08-01 lanes asked just for
  comparing options where the approach was unclear, yet the two lanes that
  wording saved from building hit stale premises instead — one task already
  handled elsewhere, one belonging behind a larger sweep. Currency and
  completeness carry the value, so the durable wording names all three. That run
  also settles where the directive belongs: `CLAUDE.md #working-method`'s
  open-question bullet was loaded in every lane and the launch text still had to
  be typed by hand, so the push needs restating where a background session's own
  contrary instructions are.

- **The prompt opens on the session being interactive**: every directive in the
  file rests on that fact — the recap has a reader, the pending diff has a
  reviewer, and a question has someone to answer it. Stated once at the top the
  fact frames all three; attached instead to the asking directive it reads as
  special pleading for that one paragraph.

- **Config work fans out like any other task**: `~/.claude` symlinks to the main
  checkout, so a worktree's hooks never run in the session editing them. That
  leaves a live firing the one thing a worktree cannot cover on its own, and
  makes installing the worktree's copy the tempting shortcut — one that hands
  every concurrent session an unreviewed hook. A throwaway session started from
  the worktree's own settings covers the firing instead, so the skill needs no
  routing rule for config tasks. The mechanism lives in
  `rules/claude-configuration.md` #live-validation rather than here, because
  that file loads whenever a session touches a hook or `settings.json` —
  including the sessions this skill never launched.

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

- **File overlap is a poor stand-in for coupling**: a textual collision is
  mechanical work, since the agent resolving it at landing holds both sides and
  the surrounding file. What no resolution recovers is a lane that needed
  another lane's outcome and never saw it, because the information sat in
  neither diff. Overlap misses coupling in both directions — it fires on lanes
  editing neighboring tracker entries, where merging is bookkeeping, and stays
  silent where two lanes share no file at all, one introducing the helper the
  other should have used.

- **Sequencing coupled tasks beats pairing them in one worktree**: a consecutive
  fanout costs a round of latency and nothing else. Pairing is right only where
  the two tasks are genuinely one decision and splitting them would yield two
  half-answers; pairing to dodge a file collision buys nothing and costs review
  surface. The lane that landed `c182c8a` through `6846c88` paired the two shell
  tasks for that reason and reached nineteen files across five commits, past
  what one review pass reads comfortably. Review attention is the practical
  bound on how wide a fanout goes, since finished branches queue for review
  serially.

- **A tracker conflict is the exception, because the tracker logs state living
  elsewhere** {#tracker-merges}: code carries enough of itself that a conflict
  is resolvable on inspection, whereas a deleted `tasks.md` entry says nothing
  about whether the task was finished or dropped, so a merged tracker can read
  as consistent and still be false. Neighboring entries collide by construction
  — deleting a finished task removes the blank line below the entry, leaving the
  deletion flush against the next task's first line, and git fuses changes that
  touch. `c182c8a` landed a tracker reviving a task that `954bb36` had already
  implemented and pruned. Keeping a tracker merge honest belongs to
  `fanout-teardown`, which owns the landing.

- **`.claude/worktrees/` needs a gitignore entry**: a worktree directory shows
  up as untracked in the repo that hosts it, which would otherwise make the
  step-2 base check report a gap for every worktree left over from an earlier
  run.
