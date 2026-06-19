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

- [ ] **Consider rotating `sessions.md` as part of the distillation skill** —
      `sessions.md` is the curated session log; it is deliberately _not_
      auto-rotated, since rotating fragments its searchable history.
      `session-tokens.py` now warns (into the diagnostic log) once it passes
      `SESSIONS_LOG_WARN_BYTES` (512 KiB). The distillation skill is the natural
      place to surface that warning visibly and decide whether to rotate or
      distill the log down.
  - Note: the shared `log_rotation.py` helper already supports this — pass
    `sessions.md` its own caps if rotation is chosen.

- [ ] **Fix `PTH105` in `session-tokens.py`'s `write_log`** — ruff flags
      `os.replace(temporary_path, log_path)` (use `Path.replace`). Pre-existing
      tech debt, not enforced on Stop (only ruff _format_ runs there, not
      _check_), so it sits latent. Swap to `temporary_path.replace(log_path)`
      and drop the now-unused `import os` if nothing else needs it.
