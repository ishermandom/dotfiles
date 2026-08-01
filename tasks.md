# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Stop `reflow_prose.py` stranding the closing quotes of a one-line
      docstring** — when a line exceeds 80 only because the trailing `"""`
      counts, the hook moves those three characters to a line of their own,
      leaving a dangling quote no one would write by hand.
  - Rationale: queued 2026-07-31, hit on four such docstrings in the bridge repo
    during a repo-wide reflow, every one of them at exactly 81 columns.
  - Note: the human fix is to reword the docstring to fit, which the hook cannot
    do. Nothing flags the long line left behind either — the global ruff config
    ignores `E501`, and `ruff format` never touches comment prose — so a fix
    that declines to act leaves no trace for a check to catch.
  - Note: leaving the line untouched, by detecting the case and declining to
    render the chunk, was built and then reverted 2026-08-01; a differently
    shaped fix is wanted. That shape also caught prose already wrapped across
    two compliant lines whose merge would have overflowed.

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

- [ ] **Rewrap Python prose in all repos, one repo at a time** — the reflow hook
      (`claude/hooks/reflow_prose.py`) rewraps a file's comment and docstring
      prose only when that file is next edited, so files untouched since the
      hook landed still carry pre-hook wrapping — and their first later edit
      mixes a mechanical rewrap into a substantive diff (e.g. the stray
      `gate_auto_tools.py` reflow diff, 2026-07-02). Rewrap each repo's Python
      files in a dedicated pass, one commit per repo, so future diffs stay
      clean.
  - Note: a Stop-time reflow safety net (mirroring the markdown design) was
    deliberately omitted, which is why this pass is manual — files changed by
    Bash or scripts stay un-reflowed until their next Edit. Revisit only if that
    gap bites in practice.

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

- [ ] **Legibility sweep of config prose** {#legibility-sweep} — apply the
      make-each-idea-separately-legible rule (rules/claude-configuration.md)
      across CLAUDE.md, rules/, docs/, and skills/. First assess all files and
      rank the worst offenders; then fix them in reviewable chunks sized to the
      user's attention budget, one chunk per review round.
  - Note: restructure only — never trim trigger phrasing or stakes while
    splitting; those are a rule's firing mechanism.

- [ ] **Add a legibility pass to the config-review skill** — a consistent pass
      applying the make-each-idea-separately-legible rule
      (rules/claude-configuration.md), so config prose stays legible as it lands
      rather than waiting for another sweep. Depends on #legibility-sweep.
  - Note: the pass also self-applies — run it on any rule text the review itself
    adds or rewrites. Self-application caught four refinements in one pass
    during the legibility rule's own drafting (2026-07-04).
  - Open question: a recurring fan-out angle in `/config-review` would do what
    the sweep does — assess, rank, then fix in review-sized chunks — so the two
    may want to be one mechanism. The task's queuing commit calls this "a
    matching pass," which reads as a recurring audit rather than only a
    self-check on text the review itself writes. Settle when the sweep lands.

- [ ] **Move the multiple-tasks rule out of the review section** — CLAUDE.md
      `## Review approach` closes with a paragraph on adding user-given task
      lists to `tasks.md` and checking in before starting. The content is sound
      but unrelated to review, so it reads as having drifted into the wrong
      section and dilutes what the heading promises.
  - Note: surfaced 2026-08-01 while unifying the review rules; left alone as out
    of scope.

- [ ] **Settle one test altitude for the two gate hooks** — `gate_git_test.py`
      drives its gate through `main()` with a real hook payload, while
      `gate_auto_tools_test.py` calls the `runs_gated_tool` predicate directly.
      Neither breaks the test-via-public-APIs rule, but sibling tests over
      near-identical PreToolUse gates shouldn't differ in depth without a stated
      reason.
  - Worktree: gate-test-altitude
  - Rationale: queued 2026-07-31 during the `gate_auto_tools_test.py`
    parametrize pass, which left the difference alone as out of scope.
  - Note: converting means first giving `gate_auto_tools.main()` the
    `stdin`/`stdout` parameters `gate_git.main()` already has — the auto-tools
    gate reads `sys.stdin` directly today, against `rules/testing.md`'s
    stream-injection rule.
  - Note: the payload level covers behavior the predicate level cannot reach —
    the fail-open path on an unparseable payload, and the shape of the emitted
    deny decision. Both are untested today.

- [ ] **Autoformat shell scripts** {#shell-autoformat} — Markdown, JavaScript,
      and Python each have a formatter wired into the edit or Stop hooks; shell
      has none, so `rules/shell.md`'s conventions and the 80-column limit rest
      on manual care alone. `claude/hooks/prettier-format.sh` carries two
      over-length lines today.
  - Worktree: shell-autoformat
  - Rationale: queued 2026-08-01, when a fix to that hook left the two long
    lines in place because tidying them by hand was out of the change's scope.
  - Note: neither `shfmt` nor `shellcheck` is installed, so this starts with
    choosing and installing a tool rather than with wiring.
  - Note: wiring a formatter up leaves the files already over 80 untouched until
    each is next edited, so clearing those is a separate pass — see
    #shell-rewrap.
  - Note: a formatter that reflows comment prose would overlap
    `reflow_prose.py`, which handles that for Python only — worth deciding
    whether shell prose belongs there instead.
  - Note: if it earns a Stop-time check, add it as a step in `stop_checks.sh`
    rather than as another parallel entry. Depends on #stop-orchestrator.

- [ ] **Rewrap the shell scripts already over 80 columns** {#shell-rewrap} — a
      formatter reaches a file only when that file is next edited, so
      #shell-autoformat leaves today's violations standing, and each one's first
      later edit then mixes a mechanical rewrap into a substantive diff. Four
      files are over: `quiet-mypy.sh`, `quiet-prettier.sh`, `statusline.sh`, and
      `hooks/prettier-format.sh`.
  - Note: that list came from `rg -n --glob '*.sh' '.{81,}'` on 2026-08-01;
    re-run it rather than trusting it, since any shell edit since then moves the
    set.
  - Note: worth doing whether or not #shell-autoformat ever lands — the pass is
    the same either way, and doing it first means the formatter's own first
    contact with each file produces no diff.

- [ ] **Determine what makes `claude agents` flag a thread as needing input** —
      the fanout workflow routes attention entirely through that view and keeps
      no status machinery of its own, so what sets a session to `waiting` is
      load-bearing yet undocumented. Establish the rule, and whether a finished
      session can be told apart from a stalled one.
  - Worktree: agents-status
  - Note: the sharpest question is `idle`, which covers both a session that
    finished and one that died mid-task. If nothing separates them, the fanout
    has no way to say which threads still owe work.
  - Note: partial findings from CLI 2.1.220, worth re-confirming rather than
    trusting — `claude agents --json` reports `status` as `busy`, `idle`, or
    `waiting` alongside a `waitingFor` reason, and live session state sits in
    `~/.claude/sessions/<pid>.json`. `waiting` appeared to track whichever
    dialog is open, with a per-dialog reason defaulting to "permission prompt".
  - Note: `state`, `detail`, and `tempo` are populated for local background
    jobs, living in `~/.claude/jobs/<id>/state.json` rather than in the session
    file — observed on CLI 2.1.220, with `state` taking `working`, `done`, and
    `blocked`, and `detail` carrying free text such as "starting…".
    `claude agents --json` surfaces `state` beside `status` but never `detail`,
    so a row reading `idle done` against `idle blocked` may be the separation
    this task wants — one reading each, so confirm before relying on it.

- [ ] **Add a rule for settling Claude Code behavior questions from the
      installed CLI** — when work is blocked on what the harness itself does,
      the shipped bundle answers it directly, yet nothing in the always-loaded
      rules points there, so the default is to guess or queue an open question.
  - Worktree: cli-behavior-rule
  - Rationale: queued 2026-08-01, after the fanout override task settled two
    blocking questions this way at one command each — whether cleanup can
    discard uncommitted worktree work, and whether `--append-system-prompt-file`
    is real despite being absent from `--help`.
  - Note: the two techniques that made it cheap are worth stating. Search for a
    behavior's distinctive log or error text rather than a common identifier —
    in a 257 MB minified bundle that is the difference between a few matches and
    a wall of them. Probe an undocumented flag by triggering its validation (a
    nonexistent path) rather than by running it, and read whether the failure
    names the flag or the value.
  - Note: search the bundle with a plain literal (`rg -a -c`) or `strings`. The
    file is effectively one enormous line, so a regex carrying wide context —
    `.{200}<literal>.{300}` — matches nothing even where the literal is present,
    and the empty result reads as "the string isn't there".
  - Note: CLAUDE.md #working-method is the likely home, but that file is already
    long and carries a queued reorganization — weigh placement against
    #consolidation-recheck. The validate-live-not-from-docs auto-memory covers
    adjacent ground and may fold in, since a global authoritative preference
    belongs in CLAUDE.md per #disprefer-memory.

- [ ] **Give config work a safe way to validate against the live harness** —
      `/fanout` tells an agent whose task changes hooks, `settings.json`, or
      anything else behind `~/.claude` to validate in the main checkout, but
      names no mechanism for doing so. Writing the change into the main checkout
      is the only way to act on that instruction, and every session on the
      machine then executes it — unreviewed and uncommitted.
  - Worktree: safe-config-validation
  - Rationale: queued 2026-08-01, after the reflow-hook agent copied its
    modified `reflow_prose.py` into the main checkout to exercise the live
    PostToolUse hook, leaving every concurrent session running that copy.
  - Note: a disposable inner session carrying the worktree's own config is one
    candidate — `claude -p --settings <rewritten>` with the hook paths pointed
    into the worktree, plus `--setting-sources` to drop the user-level entries.
    Untested; whether that cleanly excludes the live hooks is the open question.
  - Note: whichever mechanism wins, `/fanout`'s launch step has to change with
    it. The current "validate in the main checkout" wording is what licenses the
    unsafe act, so leaving it in place would preserve the edge.

- [ ] **Record how to fan out tasks that share a file** — one task per worktree
      keeps each agent's review surface small, but two tasks touching the same
      file cannot run as concurrent lanes without a landing conflict in the
      messy sense. Sequencing them across separate fanouts is the resolution,
      and nothing states it.
  - Rationale: queued 2026-08-01, after pairing two tasks into a single worktree
    to dodge that collision. One lane handled the pairing; the other spent a
    long stretch on a wrong solution, inside a diff too large to review
    comfortably.
  - Note: `fanout/notes.md` is the home. The skill never recommends assigning
    several tasks to one worker, so what is missing is maintainer rationale for
    the constraint behind that, not a change to the rules.

- [ ] **Stop worktree entry from blocking every fanned-out agent** — a
      fanned-out agent's first act is entering its worktree, and that raises a
      permission prompt the user has to answer. Each lane stalls there until
      they do, which costs a background fanout most of what makes it background.
  - Rationale: queued 2026-08-01, after most of a nine-lane fanout raised the
    prompt at once.
  - Note: the prompt names the worktree path, then calls it "a model-supplied
    worktree outside `.claude/worktrees/`" — a path that sits inside
    `.claude/worktrees/`. Its wording and its own argument disagree, on CLI
    2.1.220. Full text:

    ```text
    permission-root relocation to
    "<repo>/.claude/worktrees/<slug>" — a model-supplied worktree
    outside .claude/worktrees/
    ```
