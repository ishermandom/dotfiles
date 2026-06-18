# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Auto-allow `--` and operand pathspecs on read-only git subcommands** —
      the git gate's `_is_safe_read_arg` (`claude/hooks/gate_git.py`) treats the
      `--` operand separator as an unrecognized flag, so common read commands
      like `git diff -- <path>` and `git log -- <path>` defer to a prompt.
  - Note: `--` is a more common form than the clustered short flags the gate
    already auto-allows. Fix: recognize `--` as a safe operand separator.
  - Note: consider the attached-value short-flag form in the same pass —
    `git diff -U5` defers because `-U5` doesn't match the bare `-U` in
    `SAFE_READ_FLAGS`.
  - Note: stay fail-closed and extend `gate_git_test.py` alongside the change.

- [ ] **Build log rotation into the permission-prompt logging hook** — the hook
      that appends to `~/.claude/logs/permission-prompts.log` never rotates, so
      the file grows unbounded (already ~157KB; archived once by hand this
      session). Rotate within the hook so it stays bounded without manual `mv`.
  - Note: decide a rotation trigger (size threshold or date) and a retention
    policy for archived logs.
