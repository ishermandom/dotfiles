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

- [ ] **Generalize log rotation across the ~/.claude logs** — the
      permission-prompt hook now self-rotates, but the other unbounded logs
      under `~/.claude/logs/` (e.g. `instructions-loaded.log`, `sessions.md`)
      still grow without limit. Extract a shared rotation helper and apply it to
      each producing hook.
  - Note: model it on `log_permission_prompts.py`'s scheme (size-triggered
    rotation, date-named archives in `logs/archive/`, byte-budget pruning scoped
    per-source by filename pattern) — promote that logic into a reusable module
    the hooks import rather than duplicating it.
  - Note: per-source budgets and rotation caps will differ; thread them as
    parameters, not constants baked into the helper.
