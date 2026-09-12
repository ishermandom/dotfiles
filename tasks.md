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
  - Note: those counts predate the check runners moving to `uv run`, which now
    resolves ruff and mypy from each repo's own pins rather than from
    `~/.venvs/default` — here 0.16.4 and 2.3.1 against the 0.15.13 and 2.1.0
    they were measured under. Re-measure before acting on them. The upside is
    that which version gates a repo is now deterministic, which is what makes
    aligning three tools on one standard tractable at all.

- [ ] **Decide whether `~/.venvs/default` can go** {#retire-default-venv} — the
      toolchain no longer reaches for it: the Python hooks declare their own
      interpreter and dependencies, the check runners reach ruff and mypy
      through `uv run` against the repo being checked, and `run_tests.sh` goes
      through `uv run --project`. Work out what still would, then either delete
      the directory on both accounts and drop the activation from
      `zsh/.zshrc:101`, or write down what keeps it alive.
  - Note: it is not only ruff and mypy. Its `bin/` holds 72 entries, among them
    project entry points installed with an editable install — `clue-gen` is
    crosswords' — and unrelated tooling picked up over time: cmake, fastapi,
    huggingface-cli, mlx_lm and its dozen subcommands, playwright, streamlit,
    transformers, websockets. Deleting it takes all of those with it, so the
    question is which are still wanted and where each should come from instead.
  - Note: the activation is unconditional for interactive shells, so it also
    supplies a bare `python3` newer than Apple's 3.9.6. What depends on that,
    and whether `uv run` covers those uses, is part of the answer.
  - Note: `websockets` is there, and google-photos-deduper's `tools/cdp.py`
    needs it. That repo now declares the dependency itself, so this no longer
    waits on it — but the same question applies to every other entry in `bin/`:
    which are reached by something that declares them, and which only by hand.

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

- [ ] **Close the formatting gap that auto mode opens** {#auto-mode-format-gap}
      — auto mode instructs Claude to change files through `sed`, heredocs, and
      short scripts rather than `Edit`/`Write`, so the `PostToolUse` formatting
      hooks never fire. Under auto mode the raw edit is the norm, not the
      exception the current wiring assumes. Decide what should cover it and wire
      that up.
  - Note: the exposure is uneven. `format.sh` runs prettier and ruff at Stop, so
    markdown and Python code self-heal by end of turn — a Bash-mangled
    `tasks.md` is ugly only until the turn ends. `reflow_prose.py` is wired to
    `Edit|Write` alone, so Python comment and docstring prose written through
    Bash stays un-reflowed with nothing to catch it. See the Stop-safety-net
    note on the Python rewrap task above, which recorded that omission back when
    raw edits were rare.
  - Note: CLAUDE.md's token-and-context-efficiency section already tells Claude
    to run the formatter after a raw edit, and it did not fire in the session
    that queued this (2026-09-03) — the rule sits among token-saving advice,
    while the trigger arrives mid-Bash-call. A mechanism beats a better-worded
    rule here.
  - Open question: which mechanism. Adding `reflow_prose.py` to `format.sh`
    covers every file type uniformly and drops the rule to a backstop, but the
    reflow was kept out of Stop deliberately — recover that reasoning before
    overturning it. A `PreToolUse` nudge on file-writing Bash commands is the
    narrower alternative.

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
  - Note: sequenced behind #shell-stop-check, which is adding a check step to
    the same file. Running one `stop_checks.sh` task at a time is the user's
    call, and whichever lands first sets the shape a second check step follows.

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

- [ ] **Move CLAUDE.md's prose rules into `docs/prose.md`** {#prose-migration} —
      #plain-language, #pronouns, and #scannable-lists sit in `## Style` among
      code-style rules, though they govern prose on every surface Claude writes.
      `docs/prose.md` now holds the sentence-construction principles and reaches
      CLAUDE.md through an `@` import, so it is their natural home.
  - Note: sweep `## Documentation` and #interaction-style in the same pass —
    #substance, #explaining, and #example-first are candidates. Move a rule only
    where it shapes the prose itself; leave the ones governing when to write or
    what to deliver.
  - Note: sweep the clefts prose.md #action-in-verb now rules out — a grep
    across CLAUDE.md, rules/, docs/, skills/, and tasks.md found 22 on
    2026-09-05, including one in `skills/proofread/SKILL.md`.
  - Note: `rules/claude-configuration.md` bans the passive in rule text twice,
    under **Imperative mood** and in the finalizing slip-pattern scan, and
    prose.md #action-in-verb now bans it everywhere. Decide whether the narrower
    mentions still earn their place, and state the relationship at one site if
    they do (CLAUDE.md #canonical-location).
  - Note: prose.md keeps "the reader" throughout. The user settled this on
    2026-09-07 — the ban #reader-terminology enforces targets prose that names
    its own audience, not a guide whose subject matter is the reader. Rules
    moving in from CLAUDE.md may use the term the same way.

- [ ] **Decide which further principles `docs/prose.md` should carry**
      {#prose-additions} — three candidates, ranked below by the evidence behind
      them. Settle them together: each one that lands widens the file past Gopen
      & Swan, and the provenance line in `docs/claude-md-notes.md` should be
      written once for whichever set goes in.
  - **Single point per unit** — the strongest candidate, and the only one that
    costs no provenance: Gopen's own mid-article summary states that every unit
    of discourse, whatever its size, should serve a single function or make a
    single point, though it never reached his final seven. It reaches a scale
    the seven do not, asking whether a unit should be one unit at all. A sweep
    of the longest bullets in the config corpus on 2026-09-08 found CLAUDE.md
    #visibility carrying six directives, one of them a work-decomposition
    strategy no one would look for under a rule about status updates, and
    CLAUDE.md #canonical-location closing on cross-reference guidance that
    #cross-references already owns — so that rule breaks its own directive
    inside itself. Open question: a test this sharp fires constantly on a corpus
    built by accretion, so decide whether the findings would get acted on.
  - **Parallelism** — coordinated items in mismatched grammatical shapes make
    the reader re-parse each one against a template the first item set. Nothing
    catches it today: CLAUDE.md #scannable-lists governs whether an item's
    opening words are informative, not whether the items share a shape. A cold
    evaluation on 2026-09-07 hit non-parallel series twice in
    `skills/spec/SKILL.md` alone, both times the most noticeable problem in the
    passage, and prose.md #action-in-verb points the wrong way there by
    endorsing the one non-parallel item as the more verb-forward option. Comes
    from Strunk and from Williams's Elegance lesson.
  - **End-weight** — unresolved, and the weakest of the three on evidence: no
    instance has turned up in this corpus. Long constituents read more easily
    last, a claim about processing rather than about emphasis, so
    #stress-position does not absorb it — that principle now turns on what
    deserves emphasis, which a long constituent may not. It briefly rode in
    #stress-position's label as "or the weighty" with nothing in the body to
    explain it. Comes from Quirk et al. rather than from Gopen.
  - **Shape and coherence** — two further Williams lessons, surfaced while
    mapping his ten against prose.md and not yet weighed. Shape answers the
    question #subject-verb raises and drops: a long sentence stays readable when
    it grows rightward off a completed clause and collapses when it grows by
    nesting, so the remedy for wedged material is not only "make it shorter."
    Coherence is the paragraph-scale companion to #given-first — the same
    grammatical subject running across consecutive sentences — and it would give
    the file something above sentence scale, which every principle now lacks.
    Concision is the third lesson in that region and needs no decision:
    CLAUDE.md #substance already owns it. Note: the agent that researched
    Williams hit the session's web-search cap mid-run, so this mapping rests on
    partial sourcing — check the lesson list against a primary source before
    acting on it.
  - Worktree: prose-williams

- [ ] **Settle two weak spots in `docs/prose.md`'s existing principles**
      {#prose-weaknesses} — both surfaced in every cold evaluation of the file
      and neither is decided.
  - Open question: #emphasis-match makes two claims, and only one is its own. "A
    main clause outranks a subordinate one" is new; "a unit's end outranks its
    middle" restates #stress-position. Narrowing it to clause subordination
    would leave two clean axes — position for #stress-position, grammatical rank
    for #emphasis-match — at the cost of departing from Gopen, whose seventh
    principle deliberately generalizes his second and third. Three cold rounds
    reported the overlap, and the third found the principle never fired
    independently: every candidate was already caught by #stress-position or
    #context-first.
  - Open question: #topic-position offers no test for identifying the "story",
    which every cold round named as the file's least actionable principle. Its
    failure case — a unit that "opens on a subordinate detail" — presupposes the
    reader can already tell the subordinate detail from the story, which is the
    hard part. It also idles on imperative prose, where the topic is fixed and
    units open on verbs.

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
  - Note: `/proofread` already carries a general-purpose proofreading check
    built on the same cognitive-load lens, aimed at any project rather than at
    config prose. Weigh reusing it here before writing a second one.

- [ ] **Explore a local code review tool** {#local-review-tool} — review runs
      through chat today, where a large diff is awkward to present and to walk
      through; a local tool built for reading diffs may carry the workflow
      better.
  - Worktree: local-review-tool

- [ ] **Run `/deep-review` end to end at least once** {#deep-review-first-run} —
      the skill has never run as written. `/proofread` has, over the commit that
      split it out, so the pass and its check are exercised. Still unvalidated:
      both convergence loops, the `xhigh` built-in pass inside this wrapper, the
      inline follow-through closing each correctness round, and reading the pass
      definition from `/proofread`.
  - Note: the first run is also the cheapest test of whether one round's
    findings actually thin out by the next, which is the assumption both loops
    rest on.
  - Note: step 1 of `/ownership-walkthrough` follows `/deep-review`, so the
    first run also tests that step.
  - Open question: whether the inline follow-through actually shortens the loop.
    The run that motivated it took eighteen cold rounds, most of them reporting
    damage from earlier rounds' fixes; a comparable run finishing in a handful
    of rounds is the evidence the step works, and no improvement means the fix
    damage needs cold eyes after all.

- [ ] **Record how path-matched rules actually load** {#rules-loading-note} —
      `claude/docs/claude-md-notes.md` should carry it: only `Read` triggers a
      `path_glob_match` load, while Bash `cat`, `Edit`, and `Write` do not
      (verified 2026-09-03 against the `InstructionsLoaded` hook log and
      subagent context probes; it fires inside subagents too).
  - Rationale: auto mode steers work toward Bash and away from `Read`, so
    CLAUDE.md #new-file-rules and its dotfiles "read the matching rules file
    first" rule are what keep path-matched rules loading at all. That makes them
    load-bearing in a way neither rule currently says.

- [ ] **Find a rule-delivery mechanism that survives auto mode**
      {#rules-delivery-mechanism} — only `Read` triggers a `path_glob_match`
      load (see #rules-loading-note), and auto mode injects a reminder steering
      work toward Bash and away from `Read`. A session can therefore edit the
      files a style guide governs from end to end without that guide ever
      loading. Work out what to key the rules on instead.
  - Rationale: queued 2026-09-05. CLAUDE.md #new-file-rules and the dotfiles
    "read the matching rules file first" rule are all that keep these rules
    loading under auto mode today, and both need Claude to remember to invoke
    them — the same recall the path match exists to remove.
  - Note: the failure is silent. Nothing reports that a guide went unloaded, so
    the work looks normal and the gap shows up only as style drift later.
  - Note: whatever replaces the trigger should keep what makes path matching
    worth having — a guide costs context only in the sessions that touch its
    file type, rather than every session paying for every guide.

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

- [ ] **Tell Claude to prefer active voice over passive** — nothing binds prose
      voice today outside config files, so a passive construction reaches chat
      responses, comments, docstrings, and documentation unchallenged. CLAUDE.md
      `## Style` is the likely home, beside the other rules that reach all four
      surfaces.
  - Note: `rules/claude-configuration.md` #writing-a-rule already names passive
    constructions in its slip-pattern scan, but only for rule text in config
    files. A CLAUDE.md rule either generalizes that one or leaves it alone — see
    #canonical-location, and that file's own directive to consolidate rather
    than accumulate.
  - Open question: whether the rule earns its place at all. The necessity check
    in #writing-a-rule asks whether Claude would have gone wrong without it, and
    a general preference for active voice may already be default behavior rather
    than something a rule has to shape.

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
  - Note: sibling imports already behave the right way, verified 2026-08-22. A
    Python hook reached through the `~/.claude/hooks/` symlink gets the real
    directory as `sys.path[0]`, not the symlinked one, so `import log_rotation`
    resolves inside whichever checkout holds the hook. Only the helpers named by
    an explicit `$HOME/...` path are still pinned to the installed copy.

- [ ] **Cover `git-drop-stash.sh` with a test** — the script drops a stash, so a
      defect destroys work rather than reporting one, and its whole claim is
      behaviour under a shifting slot list. `gh-protect.sh`, `statusline.sh`,
      and the `quiet-*.sh` runners all have tests; `git-land.sh` does not, which
      is why this landed without one.
  - Note: the cases are already written — the throwaway repos built while
    validating it covered a shifted slot, a SHA no longer listed, a revision
    naming no commit, a non-commit revision, no arguments, a slot passed as the
    argument, and one SHA held at two slots. `claude/scripts/`'s framework
    (`shell-test-framework.sh`) supplies `begin_case` and `$case_dir`.
  - Note: producing the duplicate-SHA case needs a second stash pushed before
    re-storing the first — `git stash store` on the SHA `refs/stash` already
    points at writes no reflog entry, so the naive fixture silently builds
    nothing and the test passes without exercising anything.
  - Note: fix a cosmetic blemish in the same pass — a revision resolving to a
    non-commit leaks git's own `error: … expected commit type` line ahead of the
    script's message, since `rev-parse --quiet` suppresses only the
    invalid-object-name case. A `2>/dev/null` on that call settles it.

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
  - Note: the worktree default (CLAUDE.md #worktree-default) widens this past
    fanout lanes — ordinary sessions now end in a worktree teardown too, so the
    per-lane tax became a per-session one.
  - Worktree: worktree-cleanup

- [ ] **Stop the worktree git guard refusing commands that only mention `git`**
      {#guard-git-mentions} — in a worktree-isolated session the guard refused a
      `curl` of a `raw.githubusercontent.com` URL ("names git in a form too
      complex to verify"), two Python heredocs whose strings mentioned `git` in
      prose, and a session-log append whose entry did the same. None ran git;
      each cost a retry and a workaround.
  - Rationale: found 2026-09-10 in the ssh-clipboard lane.
  - Note: refusing `HOME=` and `XDG_CONFIG_HOME=` prefixes, and `zsh -c` with
    arbitrary text, guards against real git redirection and is out of scope.

- [ ] **Keep background subagents working when their session enters a worktree**
      {#guard-strands-subagents} — a research agent launched from the main
      checkout lost Bash partway through once its parent session called
      `EnterWorktree`: the worktree guard refused its commands because its shell
      still started in the shared checkout, though its work only read files
      outside the repo. Its own `EnterWorktree` from the launch directory was
      refused too, so it stopped with the research half done.
  - Rationale: found 2026-09-10 while researching osc52pty.
  - Open question: fix the guard (exempt commands that touch no repo, or carry
    running subagents into the parent's worktree), or add a rule to enter a
    worktree only while no background agents are running.

- [ ] **Let `git land` land part of a branch** — landing is all-or-nothing: the
      script fast-forwards `main` to the branch tip, so reviewing commit by
      commit and landing only what is approved means hand-rolling the
      fast-forward. Give it an optional commit argument, or decide the manual
      path is good enough and say so in the script header.
  - Rationale: queued 2026-08-26, hit while landing this repo's own CLAUDE.md
    #land-go-ahead work — the user approved commit 1 and held commit 2 for
    review, which `git land` has no way to express.

- [ ] **Measure how long the Stop hook takes, and speed up what is slow** —
      `hooks/stop_checks.sh` is the only hook wired to `Stop`, and it runs at
      the end of every turn, so whatever it costs is paid per turn. Time it end
      to end and per check inside it, then optimize whatever dominates.
  - Rationale: queued 2026-08-26 — the cost lands on every turn, making a slow
    check a tax on the whole session rather than a one-off.
  - Worktree: stop-hook-timing

- [ ] **Trim the Stop hook's report to the failing checks**
      {#stop-report-failures} — when one test suite fails, the Stop hook's
      reason carries the full output of every suite `run_tests.sh` ran, each
      passing `ok:` line included. A statusline change that broke 12 assertions
      put a couple hundred lines of mostly passing output into the session's
      context.
  - Rationale: found 2026-09-10 in the ssh-clipboard lane.

- [ ] **Move the shell environment setup from `.zprofile` to `.zshenv`**
      {#zshenv-environment} — `zsh/.zprofile` sets Homebrew's `shellenv` and
      `PLAYWRIGHT_BROWSERS_PATH`, and only a login shell reads it. Anything
      entering the account another way starts with no Homebrew, no
      `~/.local/bin`, and no browser path.
  - Rationale: found 2026-08-31, when `claudify` moved from `sudo -u … -i` to
    ssh. The login shell that `-i` had supplied disappeared, and the resulting
    shell could not find `claude` at all.
  - Note: `claudify` works around it today by ending in `exec zsh -l`. Moving
    what every shell needs into `.zshenv` lets that go back to plain `zsh`, and
    closes the same gap for every other non-login entry point.
  - Note: `.zshenv` is read by every zsh, scripts included, so only environment
    belongs there — nothing interactive, and nothing that prints.

- [ ] **Stop `install.sh` printing `chmod` noise** {#install-chmod-noise} — a
      run's output carries permission-setting chatter that buries what the
      installer actually linked.
  - Note: `install.sh` runs no `chmod` itself; it calls
    `claude/scripts/share-directory.sh`, whose `chmod -R +a` is the likely
    source. Confirm before fixing.
  - Worktree: install-chmod-noise

- [ ] **Make `install.sh -n` change nothing** {#install-dry-run} — the dry run
      promises to print planned changes without modifying anything, but
      `stow_package` runs `mkdir -p "$target"` before calling `stow`, so `-n`
      still creates every missing target directory.
  - Rationale: found 2026-09-10, when a dry run had left an empty
    `~/.config/ghostty` on the sandbox account.
  - Note: skipping the `mkdir` under `-n` is not enough on its own. `stow`
    rejects a target that does not exist, even when simulating
    (`--target value … is not a valid directory`, exit 1), so a package whose
    target is new would turn from a side effect into a failure. The dry run
    needs to report the directory it would create in place of simulating that
    package's links.

- [ ] **Cover `install.sh` with a test** {#install-test} — the script has no
      test, and its terminfo step (fresh links, reruns, replacing a stale copy,
      `-n`) was checked only by a throwaway harness. A test running the script
      against a scratch `HOME` would pin that down, and #install-dry-run's
      guarantee with it.
  - Note: the shared-cache step writes to the fixed path `/Users/Shared/cache`,
    so a real run under test needs that path injectable too.

- [ ] **Track `claudify` in this repo** {#track-claudify} — the command that
      enters the sandbox account exists only as a root-owned file at
      `/usr/local/bin/claudify`, checked in nowhere, with no history and no
      review.
  - Rationale: it gained real content on 2026-08-31 — an ssh invocation, a key
    path, a working directory — edited in place with `sudo tee`, with a dated
    copy beside it as the only backup.
  - Open question: where it installs from. Every package here targets `$HOME` or
    `$HOME/.config`, so a `bin` package linking into `$HOME/.local/bin` needs no
    root, where `/usr/local/bin` would. Only `ishermandom` runs it, so
    `accounts/ishermandom/` may fit better than the common set.
  - Note: the isolation it exists for rests on the Claude Code daemon descending
    from an ssh shell, not on `claudify` alone — see
    `claude/docs/account-setup.md` #session-backgrounding.

---

## Recurring maintenance

**Goal:** keep what this repo depends on current, on a chosen cadence rather
than by surprise. Entries here never complete — a finished run leaves the task
in place for its next turn — so never prune them.

- [ ] **Refresh pinned dependencies** {#dependency-refresh} — about monthly, run
      `uv lock --upgrade` and then `uv sync`, so everything this repo pins picks
      up improvements on a chosen schedule instead of drifting. `--dry-run`
      previews what would move, and the Stop checks report within one turn
      whether the new versions object to anything — read those before committing
      the lockfile.
  - Note: Use `git log -1 --format=%as -- uv.lock` to determine when this last
    ran.

- [ ] **Replace the remaining uses of "a reader" in CLAUDE.md**
      {#reader-terminology} — the foundational principle, the inline-comment
      rule, and two sites in #canonical-location use a term
      `rules/claude-configuration.md` bans as ambiguous. The ban binds
      CLAUDE.md, not only rules files.
  - Note: "the user" is the wrong replacement in at least the first two, where
    the audience is whoever reads the code; those sentences likely need
    restructuring to avoid naming an audience at all.
