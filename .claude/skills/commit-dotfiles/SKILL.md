---
description: Commit pending dotfiles changes one logical group at a time.
disable-model-invocation: true
---

Pending changes:

```!
git status && git diff
```

Work through the changes above in order. For each logical group:

1. **Identify the group.** Changes to the same file may span multiple logical
   topics — split them if they warrant separate commit messages. Changes across
   files that form a single coherent unit belong together.

2. **Add missing explanatory comments.** For config files (JSON, shell scripts,
   etc.), check whether the change is self-explanatory to a future reader. If
   not, add a brief inline comment before committing. Prose docs and CLAUDE.md
   don't need comments.

3. **Draft a commit message.** Subject line ≤ 72 characters; body wrapped at 80
   columns. The body should explain _why_ the change was made, not just what it
   does. If the motivation is unclear, use `AskUserQuestion` to get context
   before committing — don't guess.

4. **Commit.** Stage only the files for this group and run `git commit` directly
   — the tool will prompt for permission. Don't ask for chat approval first.

5. **Repeat** until `git status` shows no remaining tracked changes. Skip any
   files listed below under "Do not stage."

6. **Push.** Run `git push origin-https main`. The tool will prompt for
   approval.

7. **Trigger Stop hooks.** Tell the user: "Done — reply `continue` to run Stop
   hooks (linters, type-checkers, tests)." Then stop and wait. The hooks fire
   when this turn ends; they won't run until the user sends a message.

## Do not stage

- `.claude/handoff.md` — leave untracked. These files are intentionally neither
  committed nor gitignored, so they surface here as a forcing function to
  revisit the decision. TODO: decide whether session handoff logs belong in git
  at all — they may be useful history, or they may be transient noise better
  left out of the repo entirely.

Do not batch commits. Do not skip the approval step.
