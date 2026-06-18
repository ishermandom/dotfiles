# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Add a "Bash command shape" directive to guide allowlist-friendly
      commands** — distillation found prompt/correction thrash from compound or
      prefixed Bash commands recurring across ~5 sessions (compound `&&`/pipes,
      redundant `git -C <cwd>`, `2>/dev/null` redirects). The
      `claude-code-permission-matching` memory documents the mechanics but rides
      in context unapplied; a CLAUDE.md behavioral directive is the graduation
      step.
  - Note: a first draft ("prefer a single literal command whose leading text
    matches an allowlist entry…") was judged still inaccurate — nail down what's
    actually true of current matching before writing.
  - Note: the memory's empirical claims (mid-`*` not a wildcard, deny>allow,
    redirect write-scope) may be partly obsolete or unvalidated — re-validate
    live against the current Claude Code version, then word the directive to
    rest only on confirmed, version-independent behavior.
  - Note: drop `git -C` as an always-bad example (may be allowlisted now) and
    `2>/dev/null` (already covered by CLAUDE.md "don't fail silently").

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
