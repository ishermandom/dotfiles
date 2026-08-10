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

- [ ] **Surface ruff lint failures at Stop, and clear the open ones**
      {#ruff-lint-at-stop} — `claude/hooks/reflow_prose.py` carries two `B905`
      errors (`zip()` without an explicit `strict=`).
      `~/.claude/scripts/quiet-ruff.sh` reports them, yet turns end clean, so
      they have gone unnoticed (observed 2026-07-29).
  - Note: why a turn ends clean is settled — `format.sh` does lint
    (`quiet-ruff.sh` runs `ruff check --fix`) and writes what it cannot fix to
    stdout. So the findings are produced; what is missing is a path from a Stop
    hook's plain stdout to the user.
  - Note: mypy and pytest do surface at Stop, so the gap is specific to ruff
    rather than to Stop-time checks generally.
  - Note: `stop_checks.sh` discards formatter stdout, since anything a formatter
    prints would garble the halt verdict. So the fix is a lint step among its
    checks — print the findings, exit non-zero — not a change to the formatter
    step. A TODO there marks the spot.
  - Note: findings and breakage are now distinguishable by exit status — ruff
    exits 1 for findings and 2 or more when it could not run — so a lint step
    can key on the level. See the exit-status scales in
    `claude/hooks/format.sh`.
  - Note: reporting findings without halting, via a `systemMessage` field, was
    considered and dropped — a Stop hook emits one JSON object, so a halt
    verdict would have to carry the field too, and Stop's support for it is
    unverified.
  - Worktree: ruff-lint-at-stop

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

- [ ] **Resolve a hook's downstream scripts against its own checkout** — a hook
      that names a helper through `$HOME/.claude/scripts/` reaches the installed
      copy however the hook itself was reached, so a worktree's edit to that
      helper is never the code a probe exercises. `stop_checks.sh` shows the
      other shape: it finds its steps through `${BASH_SOURCE[0]}`, and they
      travel with whichever checkout holds it. Explore whether every downstream
      script can be reached that way, so a probe covers the whole chain rather
      than only its first link.
  - Rationale: queued 2026-08-04, from the format-anchoring lane, where the
    split was written up as a probe limitation rather than fixed — see
    `claude/scripts/probe_worktree_hooks.py`'s header.
  - Open question: `~/.claude/scripts/` is also the by-hand invocation path that
    CLAUDE.md points at for the `quiet-*.sh` runners, so those have to stay
    reachable there whatever the hooks come to use.

- [ ] **Record that a hook runs in the shell's current directory** — a hook
      inherits whatever directory the turn's own commands left the shell in,
      rather than the one the session started in, so any hook reaching for a
      relative path silently narrows its scope. `rules/claude-configuration.md`
      #gotchas is the home: its entries are exactly the mechanical traps that
      fail without a sound.
  - Rationale: queued 2026-08-04 from the format-anchoring lane, where nothing
    on record settled the question and an experiment had to. With the shell
    moved into `claude/hooks/`, a Markdown file edited at the repo root that
    same turn came back unformatted, while one edited in `claude/hooks/` was
    rewrapped.
  - Note: `format.sh` now anchors on the repo root, so the trap is closed where
    it was found; the entry is for whichever hook is written next.

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
