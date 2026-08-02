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
  - Worktree: stop-orchestrator
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
  - Note: the dotfiles repo's pass is done; the other repos still need theirs.
  - Note: a Stop-time reflow safety net (mirroring the markdown design) was
    deliberately omitted, which is why this pass is manual — files changed by
    Bash or scripts stay un-reflowed until their next Edit. Revisit only if that
    gap bites in practice.
  - Note: the first reflow of an un-reflowed file destroys structure, not just
    wrapping — two flag legends and both test-header run commands in the gate
    hooks were flattened into paragraphs on 2026-08-01. Scan each file for
    indented comment structure before reflowing it; which constructs survive is
    written up in `claude/hooks/reflow_prose.py`'s module header.
  - Note: before converting flattened structure to a shape the hook preserves,
    ask whether the content earns its place at all. Every run command the
    dotfiles pass found was a duplicate of what `run_tests.sh` already
    documented, so deleting the six of them beat fencing the three that broke.
  - Note: to scope a repo's pass, reflow every Python file and read the diff —
    `find . -name '*.py' | xargs python3 claude/hooks/reflow_prose.py`, then
    `git diff` — reverting it until the structure is settled.
  - Note: to show a pass touched prose only, compare each file against HEAD on
    two projections — the syntax tree with docstrings stripped, which must be
    identical, and the word sequence of all comment and docstring text, which
    should differ only where prose was deliberately cut. A second and third
    reflow confirm the result is a fixed point.

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

- [ ] **Give shell a Stop-time check** {#shell-stop-check} — shfmt and
      shellcheck run only from `claude/scripts/quiet-shell.sh`, invoked by hand,
      so nothing catches unformatted or unlinted shell the way Stop catches
      Python.
  - Rationale: the manual wrapper was chosen deliberately as the starting point;
    promoting it to a Stop-time step is the open follow-on.
  - Note: add it as a step in `stop_checks.sh` rather than as another parallel
    entry. Depends on #stop-orchestrator.
  - Note: `rules/shell.md` tells Claude to run the wrapper by hand because
    nothing else will. Correct that claim when a hook starts doing it.
  - Note: shellcheck reports 15 findings today (12 × SC2155 in
    `gh-protect-test.sh`, plus SC2164, SC2086, SC2001), so a gating check needs
    those cleared or consciously accepted first.

- [ ] **Reflow shell comment prose to 80 columns** {#shell-prose-reflow} —
      `reflow_prose.py` wraps comment and docstring prose for Python only, and
      shfmt will never do it for shell, so shell comments are hand-fitted.
  - Rationale: extending the existing reflow hook is preferred over adding a
    second mechanism for the same job.
  - Note: weigh the payoff before building — exactly 2 shell lines exceed 80
    columns as prose today, at `claude/hooks/prettier-format.sh:5` and
    `claude/scripts/quiet-mypy.sh:23`. The other 12 over-long lines are code,
    which no formatter wraps.
  - Note: take comment positions from `shfmt --to-json` rather than a line-based
    scan. `claude/scripts/gh-protect.sh` heredocs JSON and `gh-protect-test.sh`
    heredocs a stub script, both carrying `#` lines that are not comments.

- [ ] **Rewrap the shell scripts already over 80 columns** {#shell-rewrap} —
      shfmt never wraps a long line, whatever else it reformats, so every
      violation stands until a human rewrites the line itself.
  - Worktree: shell-rewrap
  - Note: re-derive the set with `rg -n '.{81,}'` over the shell files rather
    than trusting a list written here — any shell edit moves it, and a glob of
    `*.sh` alone misses the zsh files.
  - Note: the comment prose among them could be automated instead — that is
    #shell-prose-reflow. The remainder is code, which no formatter wraps.

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

- [ ] **Move the weigh-the-approach guidance into `agent-prompt.md`** — an agent
      facing an unclear approach should compare the options and ask rather than
      build the first promising one. That instruction reached the 2026-08-01
      lanes only as ad-hoc text appended to each launch command, so it holds
      only as long as whoever runs `/fanout` remembers to type it.
  - Worktree: weigh-the-approach
  - Rationale: it earned its place that run — two of nine lanes resolved by not
    building, one dropping its task as already covered elsewhere and one
    deferring behind a larger sweep.

- [ ] **Decide what a new worktree should branch from** — `worktree.baseRef` is
      unset, so every worktree starts from `origin/main`, and a fanout has to
      commit and push the tracker before launching anything. `/fanout`'s step 2
      exists only to guard that gap.
  - Open question: whether to set `worktree.baseRef` to `head`. Raised twice on
    2026-08-01 and deferred both times. `head` would still miss uncommitted
    work, so it narrows the gap rather than closing it.

- [ ] **Have Zed run the repo's formatters on save** — the formatting hooks fire
      on Claude's `Edit` and `Write` only, so a file edited by hand in Zed
      arrives unformatted and its wrapping gets settled later, by whoever next
      thinks to run a formatter. `zed/zed/settings.json` configures no
      `format_on_save` or `formatter` today.
  - Rationale: queued 2026-08-01, after two rounds of hand edits to a skill file
    each needed a formatter run afterwards to fix line wrapping.
  - Note: prettier and ruff are ordinary formatters Zed can invoke, but Python
    comment prose is reflowed by `claude/hooks/reflow_prose.py` — a bespoke
    script rather than a standard formatter. Whether that belongs in the on-save
    path, and how, is the unsettled part.

- [ ] **Give the ambiguity threshold an operative home** — low-ambiguity
      reversible work proceeds on a stated assumption, everything else clarifies
      first. Recorded only as a design stance in `docs/design.md` until that
      section was pruned; CLAUDE.md is the only place it could bind behavior.
  - Open question: whether it earns a rule at all — it restates Claude Code's
    default handling of ambiguity, so it may document existing behavior rather
    than shape it (necessity check in `rules/claude-configuration.md`
    #writing-a-rule).

- [ ] **Stop double-loading CLAUDE.md in this repo's own sessions** —
      `~/.claude/CLAUDE.md` is a symlink to `claude/CLAUDE.md`, so a session
      working in this repo loads the same 485 lines twice: once as the global
      instructions injected into every message, and again as a project file once
      anything under `claude/` is read. Every message pays for the duplicate.
  - Rationale: observed 2026-08-01 during the Python reflow pass, whose context
    carried both copies verbatim from the first message onward.
  - Note: establish the discovery path before designing a fix — whether the
    second copy arrives as a directory-scoped memory for `claude/`, or as
    ordinary project-root discovery — since the two have different remedies.
  - Note: affects the main checkout as much as a worktree; the worktree only
    made the duplication visible by putting both paths in one context.

- [ ] **Settle whether test files carry a shebang and an executable bit** — the
      eight Python test files disagree three ways: `gate_auto_tools_test.py` is
      mode 755, every other is 644, and `reflow_prose_test.py` and
      `probe_worktree_hooks_test.py` carry no shebang while the other six do.
  - Note: pytest collects them regardless, so nothing depends on either today —
    which argues for dropping both from all eight rather than adding them. The
    shell tests beside them are genuinely executed and do need theirs.
