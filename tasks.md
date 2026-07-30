# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Give the repo a project-local `.venv`** — the dev tools live in
      `/Users/claude-sandbox/.venvs/default`, inside one account's home, which
      the other account cannot read. Nothing in the repo root points an editor
      at it, and neither `/usr/bin/python3` nor `/opt/homebrew/bin/python3` has
      pytest, so Zed's language server reports `import pytest` as unresolved in
      `configure_account_remotes_test.py` (observed 2026-07-29).
  - Note: a `.venv` at the repo root is the one location both accounts and any
    editor find without per-account configuration. It needs gitignoring, and
    `pyproject.toml`'s header ("Provision the venv directly") then describes the
    wrong setup.
  - Note: check what the move does to everything that shells out to `python3` —
    `run_tests.sh`, the Stop hooks, and `~/.claude/scripts/quiet-*.sh` resolve
    whatever is on PATH, which is the per-account venv today.
  - Note: two accounts writing into one venv is the open question. The shared
    ACLs grant each of them read and write, but installed files stay owned by
    whichever account ran the install. Verify before committing to the approach.

- [ ] **Remove the duplicated test-path list** — `pyproject.toml`'s
      `[tool.pytest.ini_options] testpaths` and the explicit path arguments in
      `run_tests.sh` name the same locations. Command-line paths override
      `testpaths`, so the `pyproject.toml` value applies only to a bare
      `pytest`; the two must be edited together. Updating only `pyproject.toml`
      leaves the Stop hook — which runs `run_tests.sh` — silently not covering a
      new test file.
  - Note: the candidate fix is for `run_tests.sh` to pass no paths and pin the
    config instead (`pytest --rootdir="$root" -c "$root/pyproject.toml"`), so
    `testpaths` becomes the single source of truth. It passes paths today
    because it resolves them against the script's own location, letting the
    suite behave the same from any working directory without ever `cd`-ing.
  - Note: verify rather than assume — `testpaths` and `pythonpath` both resolve
    relative to rootdir, and a wrong rootdir would collect nothing while still
    exiting 0. Run from a subdirectory and confirm the collected count matches a
    run from the repo root.

- [ ] **Surface ruff lint failures at Stop, and clear the open ones** —
      `claude/hooks/reflow_prose.py` carries two `B905` errors (`zip()` without
      an explicit `strict=`). `~/.claude/scripts/quiet-ruff.sh` reports them,
      yet turns end clean, so they have gone unnoticed (observed 2026-07-29).
  - First step: establish why a turn ends clean while they stand. Unverified
    hypothesis — the Stop array runs `claude/hooks/ruff-format.sh`, which
    formats but never lints, while `quiet-ruff.sh` does both, leaving lint
    findings with no Stop-time path to the user. Confirm before designing a fix;
    a formatter that silently drops lint findings is a different problem from a
    check that runs and is ignored.
  - Note: mypy and pytest do surface at Stop, so the gap is specific to ruff
    rather than to Stop-time checks generally.
  - Note: if a lint check earns a place at Stop, add it as a step in
    `stop_checks.sh` rather than as a fifth parallel entry. Depends on
    #stop-orchestrator.

- [ ] **Sequence the Stop hooks through one orchestrator wrapper**
      #stop-orchestrator — same-event hooks run in parallel (verified live
      2026-07-03: two probe Stop hooks started 0.8 ms apart with fully
      overlapping 2 s sleeps; hooks-guide.md documents parallel execution and
      recommends a wrapper for ordering), so the Stop array's
      format-before-check layout provides no ordering and mypy/pytest can read
      files mid-rewrite by ruff/prettier. Rare in practice — edit-time hooks
      pre-format, so Stop-time rewrites are uncommon — but structurally unsound.
      Build `claude/hooks/stop_checks.sh` invoking prettier-format → ruff-format
      → mypy-check → run_tests sequentially, fail-fast after mypy (ratified
      2026-07-03); replace the four Stop entries with one, single ~120 s
      timeout.
  - Note: ride-alongs — run_tests.sh needs the repo-root anchor mypy-check.sh
    has, and its `-f` gate should be `-x` (quiet-tests.sh demands executable);
    add the parallel-hooks why to design.md's Hooks section. `PYTEST_FROM_HOOK`
    stays — the crosswords repos' `cluegen/{cloud,local}/run_tests.sh` read it.
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

- [ ] **Build a license-header Stop lint** — a Stop-hook check flagging source
      files that lack the license block (copyright line + SPDX identifier, per
      CLAUDE.md's License rule). Once it exists and holds, shrink the CLAUDE.md
      License rule to a pointer, per the graduation policy. Queued from the
      2026-07 adversarial review (cluster F2, ratified 2026-07-04).
  - Note: depends on #stop-orchestrator — build the check as a step in
    `stop_checks.sh`, not as another parallel Stop entry.

- [ ] **Reconcile `gate_auto_tools_test.py` with the no-loop testing rule** —
      its two tests loop over case tuples, which `rules/testing.md` prohibits in
      favor of `parametrize`; the loops exist to support a no-pytest `main()`.
      Either parametrize and drop the direct-run mode, or keep it and record the
      exception as a maintainer comment. Deferred from the 2026-07 config
      close-out.

- [ ] **Test `session_tokens.py`'s transcript-summing path** — `summed_usage`
      reads files directly, so testing it per the I/O-boundary rule
      (`rules/testing.md`) means restructuring it to accept streams, with a thin
      path-opening wrapper. Deferred from the 2026-07 config close-out.

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

- [ ] **Consider rotating `sessions.md` as part of the distillation skill** —
      `sessions.md` is the curated session log; it is deliberately _not_
      auto-rotated, since rotating fragments its searchable history.
      `session_tokens.py` now warns (into the diagnostic log) once it passes
      `SESSIONS_LOG_WARN_BYTES` (512 KiB). The distillation skill is the natural
      place to surface that warning visibly and decide whether to rotate or
      distill the log down.
  - Note: work this as part of a distill run, not standalone — the decision
    needs the log's contents in front of the user anyway.
  - Note: the shared `log_rotation.py` helper already supports this — pass
    `sessions.md` its own caps if rotation is chosen.

- [ ] **Adversarially re-check CLAUDE.md for consolidation opportunities**
      #consolidation-recheck — the 2026-07 close-out's consolidation sweep was
      an inline self-review by the session that wrote several of the candidate
      rules, and it found no folds; sympathetic review under-finds, so
      cross-check with a cold agent hunting overlapping or foldable rules across
      the always-loaded surface. Independently schedulable — run it as a
      standalone cold-agent probe, or fold it into a config-review run if one is
      imminent.

- [ ] **Reorganize CLAUDE.md intentionally** — the current section order is
      mostly historical accident. Design a deliberate order (e.g.
      most-load-bearing first, related sections adjacent) and restructure in one
      pass.
  - Note: sequence after #consolidation-recheck — landing folds first keeps them
    from churning a fresh ordering.

- [ ] **Legibility sweep of config prose** — apply the
      make-each-idea-separately-legible rule (rules/claude-configuration.md)
      across CLAUDE.md, rules/, docs/, and skills/. First assess all files and
      rank the worst offenders; then fix them in reviewable chunks sized to the
      user's attention budget, one chunk per review round.
  - Note: restructure only — never trim trigger phrasing or stakes while
    splitting; those are a rule's firing mechanism.

- [ ] **Add a legibility pass to the config-review skill** — a consistent pass
      applying the make-each-idea-separately-legible rule
      (rules/claude-configuration.md), so config prose stays legible as it lands
      rather than waiting for another sweep.
  - Note: the pass also self-applies — run it on any rule text the review itself
    adds or rewrites. Self-application caught four refinements in one pass
    during the legibility rule's own drafting (2026-07-04).

- [ ] **Convert heading-text cross-references to slugs** —
      `rules/claude-configuration.md` says to cite a section as the filename
      plus a backticked slug, never the heading text, but the repo still cites
      by heading text: `docs/design.md` in six places (e.g. "CLAUDE.md (Working
      method)", "CLAUDE.md (Interaction style)"), all four
      `docs/claude-md-notes.md` headings, and `skills/wrap-session/notes.md`
      pointing at design.md the same way. Ratified 2026-07-29 — convert the
      references rather than soften the rule.
  - Note: the slugs land on roughly seven CLAUDE.md headings (Style, Git,
    Working method, Interaction style, Review approach, Exploratory mode, Token
    and context efficiency) plus `claude-configuration.md`'s "Maintainer
    rationale" label — a small permanent cost in the always-loaded file.
  - Note: `rules/markdown.md`'s tasks-note rule teaches the outlawed form in its
    own example (`Note: settled — see spec.md (Session log).`); convert it in
    the same pass.
  - Note: `claude-configuration.md` also cites a heading in its own file ("When
    recording maintainer rationale for a skill"). The rule covers cross-file
    citation only, but a same-file citation goes stale the same way — in scope.

- [ ] **Reconsider the "inline rationale: at most one clause" cap** — the cap in
      rules/claude-configuration.md served an earlier token-limiting goal; the
      current goal is focusing attention, which may warrant fuller rationale
      where a rule is tempting to violate.
  - Rationale: queued 2026-07-04 when the legibility rule's own rationale bumped
    against the cap and had to be compressed to fit.
  - Note: recurred 2026-07-05 — drafting the new `session-context-routing.md`
    rules (necessity-test, concrete-over-abstraction) again ran long on
    rationale before trimming; second independent data point.

- [ ] **Align skill review-gating with the review-is-a-separate-axis rule** —
      `ownership-walkthrough` (frames review as settled before anything is
      committed) and `wrap-session` step 5 (withholds a durable chunk's commit
      pending the walkthrough) are now stricter than CLAUDE.md's Committing
      rule: committing never waits on review; production code is reviewed before
      push.
  - Rationale: queued 2026-07-07 when the Git-section edit decoupled review from
    committing. Pre-commit review remains a valid ordering, so the mismatch is
    posture, not breakage.
