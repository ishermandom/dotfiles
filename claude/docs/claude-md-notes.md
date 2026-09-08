# CLAUDE.md maintainer notes

Editing-time rationale for CLAUDE.md rules — the "why" a future editor needs
that a running session does not. The parallel of a skill's companion `notes.md`:
never loaded at runtime, read when editing CLAUDE.md. The file exists because
CLAUDE.md injection does not strip HTML comments (verified 2026-07-03), so
rationale cannot ride in the file for free; anything beyond the inline why a
running session needs lands here, keyed by rule.

## Prose style guide (CLAUDE.md `## Prose`)

`docs/prose.md` adapts the seven reader-expectation principles from Gopen &
Swan, "The Science of Scientific Writing" (American Scientist, 1990).

**All seven stay separate.** They collapse to three — 6 and 7 generalize 2, 3,
and 4, while 3 and 4 both govern the opening slot — but the collapsed form
trades away the concreteness that makes a rule fire. #action-in-verb names the
passive, the cleft, and the nominalization for the same reason, rather than
settling for a general "write directly".

**The guide loads through an `@` import rather than sitting in `rules/`.** Prose
turns up in every file type, so a path-matched rules file would have to match
everything. The home-relative form `@~/.claude/docs/prose.md` also sidesteps an
undocumented question — how a relative import resolves when CLAUDE.md is itself
a symlink into this repo. A fresh session started outside the repo returned all
seven anchor slugs, confirming the import fires (verified 2026-09-05).

**#stress-position does not compete with #summary-first.** The principles govern
how a discourse unit arranges its interior, so a summary — which adds a unit
ahead of the others rather than inverting one — leaves every unit still running
old-to-new. Google's guide takes the opposing position ("putting the most
important information first in a sentence"), and that one genuinely does
compete, because it reorders the same unit. Do not narrow #stress-position to
the sentence to resolve an apparent clash; the clash is with Google, not with
CLAUDE.md.

**Frequency claims rest on one measurement.** A grep across CLAUDE.md, rules/,
docs/, skills/, and tasks.md on 2026-09-05 found 22 clefts and 156 sentences
over 40 words in roughly 5,000 lines, against 6 nominalizations. #action-in-verb
and #subject-verb therefore stand on evidence; #stress-position stands on the
source alone, since violations of it resist grepping.

**#lens-not-checklist stays after the principles.** Moving it in front was
tested — four cold agents, two per arm, same file and same prompt, differing
only in where the paragraph sat. Candidate counts matched (mean 17 in both
arms), and rewrite counts differed by one (4.5 against 3.5), inside the spread
between the two runs within each arm. All four described the same procedure:
sweep the file collecting every fire, then filter in a separate pass. The
argument for moving it is that the lens frames all seven and #context-first puts
a frame before what it frames — but that assumes a reader applies the file
top-down, where this file loads whole through CLAUDE.md's import and is read
before any of it is applied.

**The `there is`/`there are` qualifier is load-bearing.** Claude reaches for the
pattern rather than the principle, flagging any expletive on sight — it happened
twice while prose.md was being drafted, once in text quoting #lens-not-checklist
in the same breath. The qualifier reads as clutter next to the cleft and the
nominalization, which need none, so the temptation to cut it will recur.

**Spot edits move the stress position.** Deleting a trailing sentence promotes
whatever preceded it into the closing slot; appending a clause displaces
whatever held it. Both operations look local while editing, and neither reads
like a change to emphasis — cutting a remedy sentence from a bullet can leave
that bullet ending on a bare qualifier, a few lines after #stress-position says
to finish on the payload. After editing prose under these principles, re-read
what each unit now ends on.

## Pronouns and demonstratives (CLAUDE.md #pronouns)

Two elements were drafted into this rule and cut; both are tempting to re-add.

The `X is what Y` shape (`the issue is what keeps it`) was drafted as a second
failure mode. The shape predicts nothing: across the motivating survey roughly
half the instances name their referent in the same sentence
(`the side is what tells pair 5 North-South from pair 5 East-West`), and in the
genuinely bad instances the vagueness comes from a trailing `it` that the main
directive already catches. The shape's real cost is three words — a concision
question, not a reference one.

`which` is absent from the trigger list despite six clause-pointing instances in
the same survey. A sentence-final `which` reaching back to a clause is ordinary
English and usually clear, so listing `which` re-creates the over-firing that
removed the shape.

Worked examples were cut rather than repaired. An example of a back-reference
defect cannot demonstrate itself: stripped of the preceding sentence,
`That is a complete parse of what the file says` reads as unremarkable, since
the referent could be a noun that simply is not shown. Such an example needs
both halves to teach anything.

## License (CLAUDE.md #license)

Beyond the inline shareability clause: applying the block uniformly across code
— not just to files likely to be shared — also keeps the professional habit
fresh.

Prose is excluded because the block buys nothing there. Markdown has no comment
syntax, so it rides in an HTML comment wedged above the title, where some
tooling reads the first line as the document title; and docs are often licensed
differently from the code they accompany, making a copied code header
affirmatively wrong. Code-only is also the dominant convention — Chromium,
Linux, Kubernetes, and Apache repos all leave docs bare. The every-file
alternative is the REUSE specification, which trades the noise for
machine-verifiable per-file licensing; curl follows it.

## Earn every sentence (CLAUDE.md #substance)

The label and slug name different things deliberately. The label states the test
applied while drafting — does this sentence carry something the reader does not
already have — because drafting is when the rule has to fire. The slug names the
property the rule protects, which is what a citation should point at.

`#concision` was the original slug and named the wrong axis: the rule governs
whether each sentence tells the reader something new, not how long the passage
runs, and a label reading "be concise" invites cutting words when the fix is
usually dropping an idea that informs nothing. "Density" was rejected for the
slug because dense shorthand is the opposite failure, the one CLAUDE.md
#explaining guards against; the word would point at both problems at once.

## Open with a standalone summary (CLAUDE.md #summary-first)

The rule answers a measurement rather than an incident. Across 377 chat messages
longer than 800 characters that asked the user for something, the request
appeared a median of 89% of the way through; restricted to messages over 2500
characters, 92%, with a median of roughly 2,700 characters standing before it.
"Asking for something" was matched by an explicit phrase list — `needs input`,
`say the word`, `your call`, `want me to`, `would you like`, `let me know`,
`shall I`, `do you want`, `which would you`, `tell me which`, `tell me where`,
`if you'd rather`, `if you'd prefer` — over every assistant message under
`~/.claude/projects/*/*.jsonl`. That definition is load-bearing, not incidental:
measuring the first question mark instead yields 71-80%.

What the rule targets is the consequence. When the request reliably sits at the
bottom, reading from the bottom is the rational strategy, and everything above
becomes material to scan past rather than read.

## Make lists scannable (CLAUDE.md #scannable-lists)

Also a measurement. Across 1,762 bullet items in the same corpus the median ran
166 characters, the 75th percentile 255, the 90th 357; 57% ran past 150
characters and 39% past 200. An item that long cannot be skimmed by reading its
opening words, so the list offers a skim it cannot deliver.

The defect is item weight, not over-use of structure — only 17% of messages
carried a header and 29% carried a bullet at all. A rule aimed at using fewer
lists would have missed.

## Prefer Edit over Write (CLAUDE.md #prefer-edit)

Cost driver: output-token generation at call time. Taking input as the 1x
baseline, per-token rates are uniform across Claude models: output 5x, cache
write 1.25x, cache read 0.1x. The generated call later sits in context at
cache-read rates, equal for both, so the comparison reduces to output generated
— Edit ≈ Σ(old+new strings), Write ≈ final file. Crossover: Write wins once
touched text approaches the whole file (deleting most of a large file, or the
edits' old_strings summing to more than Write's smaller result). The
per-operation gap is small (a ~500-line file is a few thousand output tokens vs.
~100 for a small edit — at most
~$0.30 even on Fable, the priciest
model at $50/MTok output, as of June 2026) — a
soft default, not worth a confirmation round-trip.

## No rule for choosing a search tool

A rule steering toward `rg` existed and was removed; re-adding one is the
tempting move this entry exists to head off. `grep` is what Claude reaches for
unprompted, and it is a Claude Code shell function rather than the system
binary: `ugrep -G --ignore-files --hidden -I --exclude-dir=.git …`. The
gitignore awareness and VCS skipping that argued for rg were already present,
and hidden files — which rg drops unless asked for — were already included.

rg's regex is a subset, not a superset: ugrep's `-P` handles lookaround and
backreferences, which Rust's regex crate omits by design, so `rg "colo(?!u)r"`
is a parse error where `grep -P` matches. Speed is a wash at repo scale.

The steering also cost something. `rg -r` takes a replacement, so `-rn` — the
spelling grep habits produce — silently rewrites every match to `n` and drops
line numbers, leaving output that reads as genuine. That fired four times in one
session while the rule was in force, twice reaching the user as fact. No warning
about it survives here: unprompted, `rg` is not what gets reached for, so naming
the flag would load the footgun rather than interrupt a real reach (see
#spelling-out-antipatterns).

Re-measuring is easy to get wrong. Because the shim is a shell function,
anything reaching `grep` through `subprocess` without a shell gets raw ugrep
carrying none of those flags, and appears to descend into gitignored trees.

## Cross-references (CLAUDE.md #cross-references)

The goal is anchor stability, not navigation. Nothing resolves these anchors,
and the audience is Claude or the user reading the text.

Three spellings carry three meanings, and the distinction to hold is definition
versus reference:

- `{#slug}` defines, once.
- A bare slug references.
- A backticked slug is prose about the token itself. This lets the rules state
  their own templates and examples without those becoming citations.

## Spelling out an antipattern (CLAUDE.md #spelling-out-antipatterns)

The grounding case: `shared-storage.md`'s Python tooling section says what
clearing a project's venv costs without naming the command that clears it.
Spelling it out would have been the only reason that command appeared in a
session's context, and naming it prevents nothing — the mistake it would guard
against is not one Claude was going to make unprompted.

`set -e` is the contrasting case, named outright in `rules/shell.md`. It is the
reflexive way to write the mistake, so the rule has something real to interrupt
and naming it pays for itself. The two together are the fastest way to calibrate
a new case.

The rule lives in CLAUDE.md rather than `rules/claude-configuration.md` because
warnings get written in code comments as often as in config prose, and that
rules file loads only for config paths.

What made this worth a rule is that severity is the intuitive test and the wrong
one: a worse failure pulls harder toward spelling the command out, which is
exactly backwards when Claude would never have reached for it.

## Before `git land` (CLAUDE.md #land-go-ahead)

The failure this rule exists to prevent, concretely: the user approved landing
one set of changes, and it landed. The user then requested a follow-up change,
and Claude made the edit, committed it, landed it, and pushed it without asking
again — reasoning that the user had asked for the change, so approval was
implied. What the user had approved was the state of the code before the edit,
and the edit in concept. The diff itself they never saw.

The cost showed up on `main` and stayed there. The follow-up needed a correction
of its own minutes later, by which point it had already landed and been pushed,
so it sits in the history as its own commit. Had it waited on the branch for
review, the correction would have folded into it and `main` would carry one
clean commit.

Pushes need no gate of their own, and adding one would be redundant rather than
safer. Only `main` is ever pushed, and a branch reaches `main` by landing, so
anything a push carries has already cleared the go-ahead — work ready to land is
generally ready to go out.

The trigger says any landing rather than any worktree landing for simplicity:
the general case is sufficient, even though branches here typically live in
worktrees. `git land` only ever runs from a branch regardless, so a "from a
worktree" qualifier would narrow nothing while adding a precondition that has to
hold before the rule can fire.

## Default (CLAUDE.md #worktree-default)

As of 2026-08, the built-in harness prompt says to branch first when on the
default branch, with no mention of worktrees; the user prefers worktrees, which
better support parallel work.

Strength is `prefer`, with no exception clause attached. `prefer` already
licenses skipping a worktree where it would cost more than it buys, and an
enumerated carve-out would over-fit whichever cases came to mind at the time.
