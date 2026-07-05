# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Sequence the Stop hooks through one orchestrator wrapper** — same-event
      hooks run in parallel (verified live 2026-07-03: two probe Stop hooks
      started 0.8 ms apart with fully overlapping 2 s sleeps; hooks-guide.md
      documents parallel execution and recommends a wrapper for ordering), so
      the Stop array's format-before-check layout provides no ordering and
      mypy/pytest can read files mid-rewrite by ruff/prettier. Rare in practice
      — edit-time hooks pre-format, so Stop-time rewrites are uncommon — but
      structurally unsound. Build `claude/hooks/stop_checks.sh` invoking
      prettier-format → ruff-format → mypy-check → run_tests sequentially,
      fail-fast after mypy (ratified 2026-07-03); replace the four Stop entries
      with one, single ~120 s timeout.
  - Note: ride-alongs — run_tests.sh needs the repo-root anchor mypy-check.sh
    has, and its `-f` gate should be `-x` (quiet-tests.sh demands executable);
    drop `PYTEST_FROM_HOOK` if a cross-repo grep finds no consumer; add the
    parallel-hooks why to design.md's Hooks section.
  - Note: validate after wiring per the hooks rule — one deliberate mypy-failure
    Stop cycle (failure surfaces to the user), then a clean pass.

- [ ] **Honor a project's own line length in the prose reflow hook** —
      `claude/hooks/reflow_prose.py` assumes 80 columns everywhere (see the TODO
      at `LINE_WIDTH`); read the target repo's ruff `line-length` or equivalent
      instead.
  - Note: two accepted latency levers if the hook ever feels slow, both cheaper
    than a rewrite: a shell shim gating on file suffix before Python starts (~37
    ms saved per non-Python edit), and a filler-only mode dropping prettier (~75
    ms per reflow, losing markdown-aware layout).
  - Note: a Stop-time reflow safety net (mirroring the markdown design) was
    deliberately omitted — files changed by Bash or scripts stay un-reflowed
    until their next Edit. Revisit only if that gap bites in practice.

- [ ] **Rewrap Python prose in all repos, one repo at a time** — the reflow hook
      (`claude/hooks/reflow_prose.py`) rewraps a file's comment and docstring
      prose only when that file is next edited, so files untouched since the
      hook landed still carry pre-hook wrapping — and their first later edit
      mixes a mechanical rewrap into a substantive diff (e.g. the stray
      `gate_auto_tools.py` reflow diff, 2026-07-02). Rewrap each repo's Python
      files in a dedicated pass, one commit per repo, so future diffs stay
      clean.

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
  - Note: the write-scope-gate claim currently lives in three operative homes —
    the `claude-code-write-scope-gating` memory, wrap-session SKILL.md step 4
    (run gathering commands bare), and the `append-session-log.py` header — a
    drift setup flagged by the 2026-07 adversarial review. After the
    re-validation lands, consolidate: the memory becomes the single factual
    record; the skill and the script header state only the behavior and point at
    it. Deliberately not consolidated before re-validation, to avoid enshrining
    possibly-stale facts (user-ratified 2026-07-03).
  - Note: drop `git -C` as an always-bad example (may be allowlisted now) and
    `2>/dev/null` (already covered by CLAUDE.md "don't fail silently").

- [ ] **Test `session_tokens.py`'s transcript-summing path** — `summed_usage`
      reads files directly, so testing it per the I/O-boundary rule
      (`rules/testing.md`) means restructuring it to accept streams, with a thin
      path-opening wrapper. Deferred from the 2026-07 config close-out, which
      excluded Python code changes.

- [ ] **Reconcile `gate_auto_tools_test.py` with the no-loop testing rule** —
      its two tests loop over case tuples, which `rules/testing.md` prohibits in
      favor of `parametrize`; the loops exist to support a no-pytest `main()`.
      Either parametrize and drop the direct-run mode, or keep it and record the
      exception as a maintainer comment. Deferred from the 2026-07 config
      close-out.

- [ ] **Consider rotating `sessions.md` as part of the distillation skill** —
      `sessions.md` is the curated session log; it is deliberately _not_
      auto-rotated, since rotating fragments its searchable history.
      `session_tokens.py` now warns (into the diagnostic log) once it passes
      `SESSIONS_LOG_WARN_BYTES` (512 KiB). The distillation skill is the natural
      place to surface that warning visibly and decide whether to rotate or
      distill the log down.
  - Note: the shared `log_rotation.py` helper already supports this — pass
    `sessions.md` its own caps if rotation is chosen.

- [ ] **Build a license-header Stop lint** — a Stop-hook check flagging source
      files that lack the license block (copyright line + SPDX identifier, per
      CLAUDE.md's License rule). Once it exists and holds, shrink the CLAUDE.md
      License rule to a pointer, per the graduation policy. Queued from the
      2026-07 adversarial review (cluster F2, ratified 2026-07-04).
