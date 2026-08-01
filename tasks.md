# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Stop `reflow_prose.py` stranding the closing quotes of a one-line
      docstring** — when a line exceeds 80 only because the trailing `"""`
      counts, the hook moves those three characters to a line of their own,
      leaving a dangling quote no one would write by hand.
  - Worktree: reflow-hook
  - Rationale: queued 2026-07-31, hit on four such docstrings in the bridge repo
    during a repo-wide reflow, every one of them at exactly 81 columns.
  - Note: the human fix is to reword the docstring to fit, which the hook cannot
    do. So detecting the case and leaving the line untouched may beat splitting
    it — a silent bad split is worse than a visible violation, which a width
    check still catches.

- [ ] **Reconsider the "inline rationale: at most one clause" cap** — the cap in
      rules/claude-configuration.md served an earlier token-limiting goal; the
      current goal is focusing attention, which may warrant fuller rationale
      where a rule is tempting to violate.
  - Rationale: queued 2026-07-04 when the legibility rule's own rationale bumped
    against the cap and had to be compressed to fit.
  - Note: recurred 2026-07-05 — drafting the new `session-context-routing.md`
    rules (necessity-test, concrete-over-abstraction) again ran long on
    rationale before trimming; second independent data point.

- [ ] **Sequence the Stop hooks through one orchestrator wrapper**
      {#stop-orchestrator} — same-event hooks run in parallel (verified live
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

- [ ] **Give the repo a project-local `.venv`** — the dev tools live in
      `/Users/claude-sandbox/.venvs/default`, inside one account's home, which
      the other account cannot read. Nothing in the repo root points an editor
      at it, and neither `/usr/bin/python3` nor `/opt/homebrew/bin/python3` has
      pytest, so Zed's language server reports `import pytest` as unresolved in
      the repo's test files (observed 2026-07-29).
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
  - Worktree: test-paths
  - Note: the candidate fix is for `run_tests.sh` to pass no paths and pin the
    config instead (`pytest --rootdir="$root" -c "$root/pyproject.toml"`), so
    `testpaths` becomes the single source of truth. It passes paths today
    because it resolves them against the script's own location, letting the
    suite behave the same from any working directory without ever `cd`-ing.
  - Note: verify rather than assume — `testpaths` and `pythonpath` both resolve
    relative to rootdir, and a wrong rootdir would collect nothing while still
    exiting 0. Run from a subdirectory and confirm the collected count matches a
    run from the repo root.

- [ ] **Honor a project's own line length in the prose reflow hook** —
      `claude/hooks/reflow_prose.py` assumes 80 columns everywhere (see the TODO
      at `LINE_WIDTH`); read the target repo's ruff `line-length` or equivalent
      instead.
  - Worktree: reflow-hook
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
      CLAUDE.md #license). Once it exists and holds, shrink the CLAUDE.md
      #license rule to a pointer, per the graduation policy. Queued from the
      2026-07 adversarial review (cluster F2, ratified 2026-07-04).
  - Note: depends on #stop-orchestrator — build the check as a step in
    `stop_checks.sh`, not as another parallel Stop entry.

- [ ] **Lint slug anchors against their citations** — the cross-reference
      convention now spans CLAUDE.md, `rules/`, `docs/`, `skills/`, and
      `tasks.md`, but the rename-and-removal upkeep CLAUDE.md #cross-references
      calls for is manual, so a renamed or deleted anchor leaves a dangling
      citation that nothing catches. Compare braced definitions against bare
      citations and report both directions — dangling citations, and anchors
      nothing cites (anchoring is meant to be lazy, so an uncited anchor is also
      a defect).
  - Note: a throwaway pass over every `*.md` ran clean in both directions on
    2026-07-31, so the convention holds today; nothing was kept.
  - Note: depends on #stop-orchestrator — build it as a step in
    `stop_checks.sh`, not as another parallel Stop entry.

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
      {#consolidation-recheck} — the 2026-07 close-out's consolidation sweep was
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
  - Note: a candidate organizing signal, found while placing the pronouns rule —
    `## Style` holds prose rules that reach chat responses, `## Documentation`
    holds documentation-only ones. The scope clauses on "Plain language over
    jargon" and "Concepts over implementation" differ by exactly that item.

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

- [ ] **Align skill review-gating with the review-is-a-separate-axis rule** —
      `ownership-walkthrough` (frames review as settled before anything is
      committed) and `wrap-session` step 5 (withholds a durable chunk's commit
      pending the walkthrough) are now stricter than CLAUDE.md #review-axis:
      committing never waits on review; production code is reviewed before push.
  - Rationale: queued 2026-07-07 when the Git-section edit decoupled review from
    committing. Pre-commit review remains a valid ordering, so the mismatch is
    posture, not breakage.

- [ ] **Override the background harness's commit-push-and-PR demand in
      `/fanout`** — a `claude --bg` session is instructed to commit its work,
      push its branch, and open a draft PR. All three contradict CLAUDE.md
      (never commit dotfiles unasked; "only `main` pushes") and the fanout
      workflow, which ends in a local `git land`. Each agent has to notice and
      resolve the conflict on its own.
  - Worktree: fanout-harness
  - Rationale: queued 2026-07-31, after the zed-prettier agent hit the conflict
    and reasoned it out before reporting. The user confirmed the local workflow
    supersedes the harness default, and wants each worktree's work left as a
    pending diff — easier to review than commits an agent already made.
  - Note: `--append-system-prompt` on the launch command is the likely
    mechanism. The launch step (4) currently directs "Pass no other flags by
    default", reasoning that CLAUDE.md already governs agentic behavior — the
    premise this task corrects, so that line needs updating in the same edit.
  - Open question: whether a background session's worktree survives with
    uncommitted work or can be discarded at exit. If work can be lost, telling
    agents not to commit trades a review cost for a data-loss risk, and the fix
    belongs in the landing flow instead.

- [ ] **Settle one test altitude for the two gate hooks** — `gate_git_test.py`
      drives its gate through `main()` with a real hook payload, while
      `gate_auto_tools_test.py` calls the `runs_gated_tool` predicate directly.
      Neither breaks the test-via-public-APIs rule, but sibling tests over
      near-identical PreToolUse gates shouldn't differ in depth without a stated
      reason.
  - Rationale: queued 2026-07-31 during the `gate_auto_tools_test.py`
    parametrize pass, which left the difference alone as out of scope.
  - Note: converting means first giving `gate_auto_tools.main()` the
    `stdin`/`stdout` parameters `gate_git.main()` already has — the auto-tools
    gate reads `sys.stdin` directly today, against `rules/testing.md`'s
    stream-injection rule.
  - Note: the payload level covers behavior the predicate level cannot reach —
    the fail-open path on an unparseable payload, and the shape of the emitted
    deny decision. Both are untested today.

- [ ] **Make `quiet-tests.sh` scope to the paths it is given** — CLAUDE.md
      advertises
      `~/.claude/scripts/quiet-{tests,mypy,ruff,prettier}.sh [paths]`, and
      `quiet-mypy.sh` and `quiet-ruff.sh` do honor paths. `quiet-tests.sh`
      forwards its arguments to `run_tests.sh`, which already passes
      `claude/hooks` and `claude/scripts` ahead of them, so a path argument
      never narrows the run — the full suite executes either way, silently. Have
      `run_tests.sh` fall back to the two directories only when given no
      arguments.
  - Worktree: test-paths
  - Rationale: queued 2026-07-31 after a mid-turn check aimed at one test file
    ran all 252 tests and looked like it had worked.
  - Note: `-k <expression>` does narrow the run today — the workaround until the
    argument handling changes.

- [ ] **Autoformat shell scripts** — Markdown, JavaScript, and Python each have
      a formatter wired into the edit or Stop hooks; shell has none, so
      `rules/shell.md`'s conventions and the 80-column limit rest on manual care
      alone. `claude/hooks/prettier-format.sh` carries two over-length lines
      today.
  - Rationale: queued 2026-08-01, when a fix to that hook left the two long
    lines in place because tidying them by hand was out of the change's scope.
  - Note: neither `shfmt` nor `shellcheck` is installed, so this starts with
    choosing and installing a tool rather than with wiring.
  - Note: a formatter that reflows comment prose would overlap
    `reflow_prose.py`, which handles that for Python only — worth deciding
    whether shell prose belongs there instead.
  - Note: if it earns a Stop-time check, add it as a step in `stop_checks.sh`
    rather than as another parallel entry. Depends on #stop-orchestrator.

- [ ] **Determine what makes `claude agents` flag a thread as needing input** —
      the fanout workflow routes attention entirely through that view and keeps
      no status machinery of its own, so what sets a session to `waiting` is
      load-bearing yet undocumented. Establish the rule, and whether a finished
      session can be told apart from a stalled one.
  - Note: the sharpest question is `idle`, which covers both a session that
    finished and one that died mid-task. If nothing separates them, the fanout
    has no way to say which threads still owe work.
  - Note: partial findings from CLI 2.1.220, worth re-confirming rather than
    trusting — `claude agents --json` reports `status` as `busy`, `idle`, or
    `waiting` alongside a `waitingFor` reason, and live session state sits in
    `~/.claude/sessions/<pid>.json`. `waiting` appeared to track whichever
    dialog is open, with a per-dialog reason defaulting to "permission prompt".
  - Note: that session schema also carries `state`, `detail`, `tempo`, and
    `needs` fields which local sessions leave unset. They may belong to the
    cloud-agent surface, which would explain why its richer `blocked` state
    never shows up locally.

- [ ] **Have each fanned-out agent open by recapping its task** — `/fanout`
      hands an agent a worktree handle and nothing more, and the
      background-agent view lists only that handle, so nothing says which
      tracker task a session actually picked up short of attaching to it.
  - Rationale: queued 2026-08-01 after a three-lane fanout, where the lane names
    alone did not convey what any agent was working on.
  - Note: the recap belongs in whatever text `/fanout`'s launch step passes to
    the agent. Another queued task rewrites that same step, so land the two
    together or sequence this one after it rather than editing the step twice.
