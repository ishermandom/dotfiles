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

- [ ] **Re-examine the shared uv cache as a sandbox-escape path**
      {#shared-cache-threat-model} — `uv/uv.toml` sets `cache-dir` machine-wide,
      so every uv project on this machine hardlinks its packages out of
      `/Users/Shared/cache/uv`, including projects outside `/Users/Shared`.
      Hardlinks share an inode, so a write by the sandbox account to a cached
      file changes that package in every venv linked from it — and the account
      owning that venv executes the change on its next import. Decide whether
      that is acceptable, and constrain it if not.
  - Note: the sharp part is reach beyond the shared tree. Inside
    `/Users/Shared/code` the venv adds nothing new — the sandbox account can
    already write the source there, so it can already run code as the other
    account, which `account-setup.md`'s threat model accepted. A project in a
    private directory was never part of that bargain, and the shared cache
    reaches it.
  - Open question: whether any uv project exists outside `/Users/Shared`. If
    none does and none is planned, the exposure is theoretical and the entry can
    say so and close.
  - Note: uv offers no per-path cache scoping, so the realistic options are one
    shared cache or none. A per-account cache restores isolation but gives up
    the hardlinking that makes a venv writable by both accounts — that is the
    trade to weigh. uv verifies package hashes against the lockfile when
    installing, never on read, so a later write to a cached file goes unnoticed.

- [ ] **Refresh the Ollama section of `claude/docs/shared-storage.md`** — it
      describes an interim that has ended. Homebrew's multi-user breakage is
      fixed and `ollama` is installed at `/opt/homebrew/bin/ollama` (0.32.5), so
      the shared brew binary the section anticipates is already in place. Record
      that instead, and delete the leftover unpacked copy at `~/tmp/ollama` on
      the sandbox account.

- [ ] **Bring every other repo under the same setup** {#repo-tidy-up} — each
      repo under `/Users/Shared/code` should carry a `.venv` its editor finds
      and its `run_tests.sh` uses, so the arrangement is uniform rather than
      true of the dotfiles repo alone. Per repo: a `pyproject.toml` declaring
      dependencies, `[tool.uv] package = false` where nothing is meant to be
      installable, `uv sync`, `.venv/` gitignored, and `run_tests.sh` going
      through `uv run --project`.
  - Note: the state as surveyed. `bridge` is already the model — a uv workspace
    with a shared-tree `.venv` since July — and needs only the machine config.
    `google-photos-deduper` carries a legacy `.pytest.ini` and pins Python 3.9.
    `bridge-scoresheets` declares no dependencies at all. The crosswords repos
    are installable packages on purpose, for the `clue-gen` entry point, and
    should stay that way, though `uv sync` would still give each an
    editor-visible `.venv`. Record that reasoning in the crosswords repo, where
    the packaging decision belongs, rather than in the shared design doc.
  - Note: keep `[project] name` matching the directory. uv derives the venv's
    prompt from it and Zed's status bar shows that prompt, so a copied name
    makes the editor look like it picked another project's venv.
  - Note: a repo Zed has opened before may hold a toolchain choice predating its
    `.venv`, which survives reopening. Zed keys that choice by path, in
    `~/Library/Application Support/Zed/db/`; re-picking from the toolchain
    selector clears it. Fresh repos autodiscover correctly with no interaction.

- [ ] **Align mypy, ruff, and basedpyright on one standard** — the three
      disagree about this codebase, and only mypy's verdict is enforced.
      `mypy --strict` passes and gates at Stop; basedpyright at its own default
      reports ~130 findings, and at pyright's `standard` still reports six. Work
      out which checks the repo actually wants, which tool should own each, and
      configure to match, rather than letting the editor disagree with the gate.
  - Note: most of the ~130 are style opinions against deliberate choices —
    sibling imports in non-package directories, discarded return values,
    implicit string concatenation. Roughly 67 are `Any` leaking from bashlex,
    which ships no stubs; mypy could enforce the same through
    `--disallow-any-expr`, which `--strict` does not include.
  - Note: the six that survive at `standard` are all unavoidable, and both live
    in `gate_git.py`. `bashlex` is imported under a `try` guarded by a boolean
    no checker can follow, and `bashlex.ast.node` assigns its attributes via
    `self.__dict__.update(kwargs)`, so the `_Node` protocol it satisfies at
    runtime cannot be verified statically.

- [ ] **Decide whether `[tool.pytest.ini_options] pythonpath` earns its place**
      — the suite passes with it disabled, because pytest inserts each test
      file's own directory under its default `prepend` import mode and every
      first-party import here is a sibling. Its comment claims it is needed for
      exactly those imports, which is untrue.
  - Note: the entry stops being inert under `--import-mode=importlib`, which
    inserts no basedirs. Keeping it as deliberate insurance is defensible; the
    comment needs correcting either way.

- [ ] **Have the hooks find their own tools** {#self-describing-hooks} — every
      hook reaches its Python dependencies through PATH, which `zsh/.zshrc`
      sets, so a hook running outside a shell that sourced it loses them
      silently. Resolve the repo's `.venv` from each script's own location
      instead, and the shell config stops being load-bearing for anything but
      interactive convenience.
  - Note: both mechanisms are verified. A Python hook reached through
    `~/.claude/hooks/` resolves `Path(__file__).resolve().parents[2]` to the
    real checkout, and putting that venv's `site-packages` on `sys.path` imports
    `bashlex` under the system interpreter — no re-exec, no second process. A
    shell hook does the same from `${BASH_SOURCE[0]}`, the idiom
    `stop_checks.sh` already uses to find its steps.
  - Note: build the `site-packages` path from `sys.version_info` rather than
    writing the version out. A mismatch between the running interpreter and the
    venv's would leave the path absent, skipping the injection and degrading
    `gate_git.py` to `_HAS_BASHLEX = False` — log that rather than pass quietly.
  - Note: this settles the open question in #hook-downstream-scripts and in
    "Factor out resolving a repo root". Resolving a script's own real path
    reaches the checkout that holds it, so a shared helper travels with it.

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
  - Note: the first reflow of an un-reflowed file can change structure, not just
    wrapping — adjacent lines the author meant as separate paragraphs merge into
    one, which a `Usage:` line abutting the prose below it, or a label line
    abutting its note, both hit. The shell pass found six such sites. Read every
    file's diff rather than assuming the pass is mechanical; which constructs
    survive is written up in `claude/hooks/reflow_prose.py`'s module header.
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
  - Note: build the check as a step in `stop_checks.sh`, not as another parallel
    Stop entry.

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
  - Note: build it as a step in `stop_checks.sh`, not as another parallel Stop
    entry.

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

- [ ] **Explore having `pre-compact` update the session log** — only
      `wrap-session` writes a reflection entry today, so a session that compacts
      several times reflects at the end on whatever survived the last summary;
      the transcript its earlier stretches ran in is gone by then. `pre-compact`
      runs while that transcript is still whole and already routes durable
      context, which makes it the natural place to capture the stretch about to
      be summarized.
  - Open question: how to measure a long-running session at all. `wrap-session`
    keys one entry per session on `<!-- session: <id> -->` and the SessionEnd
    hook appends the final `tokens:` line at that marker, so several entries
    sharing one id needs a call — one entry appended to per compact, or separate
    entries with the token line landing on just one.
  - Note: `wrap-session` already carries a guard for a second run in one session
    ("evaluate only the work since that run"), which is this problem in a
    different shape.
  - Note: reflection-entry count is what `distillation_backlog.py` reports
    against its suggest-a-distill threshold, so writing more entries per session
    moves when that fires.
  - Note: two entries under one id already happens without compaction. A session
    whose process exits and restarts keeps its id, so SessionEnd writes a
    stats-only entry for the first stretch and `wrap-session` later writes a
    reflection entry beside it — both carrying the same marker, which is what
    the open question above has to resolve. Seen 2026-08-20 for session
    a80e121e.

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
  - Rationale: running `quiet-shell.sh` by hand was chosen deliberately as the
    starting point; promoting it to a Stop-time step is the open follow-on.
  - Note: the two halves now want different homes — shfmt fits `format.sh`'s
    runner list, where findings deliberately do not halt, while shellcheck has
    to be its own check step in `stop_checks.sh` to gate at all. Neither belongs
    in a parallel Stop entry. `quiet-shell.sh` runs both from one invocation, so
    separating them is part of the work.
  - Note: `rules/shell.md` tells Claude to run `quiet-shell.sh` by hand because
    nothing else will. Correct that claim when a hook starts doing it.
  - Note: shellcheck reports 15 findings today (12 × SC2155 in
    `gh-protect-test.sh`, plus SC2164, SC2086, SC2001), so a gating check needs
    those cleared or consciously accepted first.
  - Worktree: shell-stop-check

- [ ] **Have Zed run the repo's formatters on save** — the formatting hooks fire
      on Claude's `Edit` and `Write` only, so a file edited by hand in Zed
      arrives unformatted and its wrapping gets settled later, by whoever next
      thinks to run a formatter. `zed/zed/settings.json` configures no
      `format_on_save` or `formatter` today.
  - Rationale: queued 2026-08-01, after two rounds of hand edits to a skill file
    each needed a formatter run afterwards to fix line wrapping.
  - Note: prettier and ruff are ordinary formatters Zed can invoke, but comment
    prose is reflowed by `claude/hooks/reflow_prose.py` — a bespoke script
    rather than a standard formatter. Whether that belongs in the on-save path,
    and how, is the unsettled part.

- [ ] **Give the ambiguity threshold an operative home** — low-ambiguity
      reversible work proceeds on a stated assumption, everything else clarifies
      first. Recorded only as a design stance in `docs/design.md` until that
      section was pruned; CLAUDE.md is the only place it could bind behavior.
  - Open question: whether it earns a rule at all — it restates Claude Code's
    default handling of ambiguity, so it may document existing behavior rather
    than shape it (necessity check in `rules/claude-configuration.md`
    #writing-a-rule).

- [ ] **Resolve a hook's downstream scripts against its own checkout**
      {#hook-downstream-scripts} — a hook that names a helper through
      `$HOME/.claude/scripts/` reaches the installed copy however the hook
      itself was reached, so a worktree's edit to that helper is never the code
      a probe exercises. `stop_checks.sh` shows the other shape: it finds its
      steps through `${BASH_SOURCE[0]}`, and they travel with whichever checkout
      holds it. Explore whether every downstream script can be reached that way,
      so a probe covers the whole chain rather than only its first link.
  - Rationale: queued 2026-08-04, from the format-anchoring lane, where the
    split was written up as a probe limitation rather than fixed — see
    `claude/scripts/probe_worktree_hooks.py`'s header.
  - Open question: `~/.claude/scripts/` is also the by-hand invocation path that
    CLAUDE.md points at for the `quiet-*.sh` runners, so those have to stay
    reachable there whatever the hooks come to use.

- [ ] **Factor out resolving a repo root** — `rev-parse --show-toplevel` is
      spelled out at eight sites across `claude/hooks/` and `claude/scripts/`,
      in two shapes: the root of the current directory, falling back to that
      directory, and the root of a directory named by the caller. One helper
      taking an optional directory covers both.
  - Rationale: queued 2026-08-11 from the ruff-lint lane, where `ruff-lint.sh`
    added another copy of the first shape and the user asked whether it should
    be shared.
  - Note: where the helper lives is the open part — a hook that sources it
    through `$HOME/.claude/scripts/` reaches the installed copy, so a worktree's
    edit to the helper would go untested. Depends on #hook-downstream-scripts.

- [ ] **Say how to validate a hook's steps from a worktree** —
      `rules/claude-configuration.md` #worktree-live-validation splits the world
      into scripts, run from their path in the worktree, and hooks, fired with
      `probe_worktree_hooks.py`. It leaves the third case unaddressed: a script
      reached only through a hook, such as a `stop_checks.sh` step. Running the
      registered hook script straight out of the worktree covers such a step end
      to end, and spends no model turn.
  - Rationale: queued 2026-08-04 from the format-anchoring lane, where the
    binary framing sent the first instinct to the probe and the user flagged it.
    The direct run then validated the whole chain, `format.sh` included.

- [ ] **Stop restating the `~/.claude` warning in fanout launch prompts** —
      `fanout/SKILL.md` step 4 has the coordinating session tell a lane, in its
      launch prompt, that `~/.claude` paths resolve to the main checkout. The
      lane gets that anyway: `rules/claude-configuration.md`
      #worktree-live-validation carries it, and that file path-matches
      `claude/hooks/**` and `claude/rules/*.md` among others, so it loads the
      moment a lane opens the file it came to edit. Either delete the paragraph
      or narrow it to executable config.
  - Rationale: queued 2026-08-04. `fanout/notes.md` already argues this position
    for the skill as a whole — config work needs no routing rule, because the
    mechanism lives in the rules file and that file loads on its own. Step 4 is
    the one place the skill does not follow the argument.
  - Note: composing the warning also pulls against step 1's no-prework
    directive, since judging whether a task qualifies means working out which
    files it touches and how each one is reached.
  - Note: the paragraph over-fires on prose. A lane editing
    `rules/claude-configuration.md` was sent the warning on 2026-08-04, though a
    file only ever read as context has nothing to fire and so no
    installed-versus-worktree hazard.

- [ ] **Stop the worktree cleanup tripping on already-landed diffs** —
      `fanout-teardown` step 7 removes the lane's worktree, and on every
      teardown the removal errors out over uncommitted diffs. The work is
      already on `main` by then, so the lane spends a turn confirming that
      before retrying the removal. Research where the check and the repository
      disagree, and whether a different removal path or teardown order drops the
      round trip.
  - Rationale: queued 2026-08-10. The error recurs on every lane, so it is a
    per-lane tax on fanouts rather than a one-off.
  - Note: `fanout/notes.md` records the three removal paths — `ExitWorktree`'s
    remove path, the interactive exit dialog, and `git worktree remove` — and
    that both automatic cleanups deliberately refuse a worktree whose
    `git status --porcelain` is non-empty. Which path step 7 takes, and what it
    counts as dirty, is where to start.
  - Note: `ExitWorktree`'s refusal is not about uncommitted diffs at all. With a
    clean `git status`, and the branch tip identical to both `main` and
    `origin/main`, it still refused: "Worktree has 3 commits on <branch>.
    Removing will discard this work permanently." So it counts commits on the
    branch without asking whether `main` already holds them, and landing first
    cannot satisfy it — only `discard_changes: true` clears it. Seen 2026-08-20.
  - Worktree: worktree-cleanup
