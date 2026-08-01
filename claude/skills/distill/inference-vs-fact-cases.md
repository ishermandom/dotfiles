# Unverified claims stated as fact: case record

Accumulated evidence for one open question in `SKILL.md`'s **Pending
evaluations**: what, if anything, would actually stop Claude from stating
unchecked claims with the confidence of checked ones.

CLAUDE.md #inference-vs-fact already covers this and was loaded in every session
below. It was violated in roughly thirteen of the seventy-nine reflection
entries between 2026-06-18 and 2026-07-30 — the most frequently violated rule in
that span by a wide margin. The 2026-07-30 distillation run could not produce a
fix it could argue would fire, so the evidence is parked here instead of spent
on a rule that would not work.

These cases are preserved rather than left in the session log because each
distillation run scopes to entries after the most recent marker. The 2026-07-30
marker puts all of them out of scope permanently; without this file they stop
being visible to the process that would use them.

## What a future run should add

Append new instances as they occur, in the same shape: what was claimed, what
was true, how it surfaced, and what evidence was available at the time. The last
element matters most — a mechanism can only key on something present at the
moment of the claim.

Resolve the question when a candidate mechanism survives the checks in
`rules/claude-configuration.md` #writing-a-rule, particularly
**recognizability** and **anchor to transitions, not ambient conditions**. Drop
the question if the pattern stops recurring.

## Approaches already rejected

Re-proposing one of these needs new reasoning, not new instances.

- **Adding the "felt familiarity" tell to the existing rule.** Rejected: it
  describes the failure more accurately without giving the rule a moment at
  which to fire.
- **Enumerating the recurring kinds of claim** — a measurement, a count, what a
  command printed, why code does something, who wrote something. Rejected: a
  closed list over-fits and reads as excluding everything not named.
- **"Before asserting, search this session's own earlier tool results."**
  Rejected by the user as unlikely to work, though it covers cases 9, 11, and 12
  below, where the contradicting evidence was already in context.
- **A hook.** No mechanical signal distinguishes a verified claim from an
  unverified one.
- **Line-width and column checks.** Proposed as an example, then withdrawn:
  Markdown runs through Prettier and Python through the reflow hook on every
  edit, so those checks re-do work already done and should not happen at all.
  Only shell scripts lack a formatter, and there the tool is `wc -L`, never
  `awk length`, which counts bytes and overcounts em dashes. This is a
  re-verification problem, not an unverified-claim problem.

## Structural diagnosis

The rule is written as an ambient condition — "never state an unverified claim
with the confidence of a verified one" describes a state that holds
continuously, so no moment triggers it. `rules/claude-configuration.md` names
this shape directly under **Anchor to transitions, not ambient conditions**.

Where the claim lands may matter to any future mechanism, so the cases are
grouped that way. Claims written into files persist as misinformation until
someone catches them, and a self-review seam already exists there. Claims made
in chat are corrected sooner but have no identified seam.

## Cases: claims written into files

**2026-07-07 · docs.** Asked to explain an earlier claim, Claude described the
repository's own git landing mechanism from memory rather than reading it —
claiming it rebased branches directly, used `--force-with-lease`, and relied on
the reflog as a safety net. The script does fast-forward-only landing, and
branches are never pushed. Cost a correction round and a second edit to the
design document. The request itself ("explain what you meant by X") is a request
to ground a prior claim.

**2026-07-21 · code review.** Empirical numbers written into a docstring without
the measurement setup they came from; user probing exposed the figures as mixing
full-width and sliced measurements.

**2026-07-22 · code comment.** Asserted unprompted that a value was re-emitted
at board level "so it counts toward review priority" — written as settled design
intent when nothing in the codebase reads that field for ranking, and the
interface that would is unbuilt. Compounded by attributing the comment to "an
earlier author" when Claude had written it earlier in the same session, copying
the rationale from a sibling comment without checking whether it applied. One
search would have caught both; it was run only after the user pushed back twice.

**2026-07-24 · code comments.** Two domain claims written as fact: that only one
direction carries the par contract, and that a mirroring guard protects against
"two directors" — it also covers one director's in-person and online copies.
Both were unverified inferences the user caught. The entry notes the rule
"dropped under review volume."

**2026-07-28 · code comment.** A comment describing a code layout ("one source
line per line of the file") was written in the same turn the formatter collapsed
that layout, leaving the comment false immediately.

## Cases: claims made in chat

**2026-06-18 · permissions.** Claimed twice, with confidence, that reading
GitHub repository rulesets required an Administration permission scope and that
a token carrying only Contents read/write would be refused. Never tested. The
token was already in the credential store, and one run of the protection script
disproved it — the means to test was already at hand.

**2026-07-02 · hardware.** Stated the machine had 16 GB of memory as established
fact, read off a heuristic in another tool's log. It had 32 GB, and the user
knew.

**2026-07-03 · experiment conclusions.** About eight corrections in one session,
all the same failure: conclusions stated beyond their evidence class — a
"capability limit" inferred from five kept rows out of eleven, "the last wording
pass that might pay off", "the spec is normative", and a quality approach
declared rejected on one variant with asymmetric tuning. Each was an assumption
or a single-probe inference presented as a settled finding. Separately, the same
session inherited a prior session's diagnosis — that a desktop application's
process reaper was killing background watcher processes — and restated it as
established. That session was running under the terminal command-line tool, not
the desktop application, and watchers still died, so the attribution was
unverified to wrong.

**2026-07-14 · web search summary.** Blended a hosting platform's own GitHub
integration with an unrelated third-party deployment action while summarizing
search results, and stated it confidently. Retracted when the user asked a
precise follow-up. The primary source was never opened to separate two
similarly-purposed things.

**2026-07-21 · image processing.** Concluded a scoresheet form version was
"undigitizable" after a detector failed on every slice. The actual cause was
that the image had been rendered with transparency, and the transparent
background became black under grayscale conversion, compounded by a misreading
of the form's stylesheet. Two user turns to unwind ("did you rotate the PDF?",
"have you actually taken a look at the PDF?"). A clean render failing on every
slice was the signal to view the exact post-conversion input.

**2026-07-21 · git state.** Read an empty `git status --porcelain <path>` as
meaning the file was untracked, then asserted the deletion was unrecoverable and
there was nothing to commit. The file existed on disk while the status output
was empty — that combination means tracked-and-clean, or ignored. One
`git ls-files` would have disambiguated. Stated with verified-fact confidence
twice; the user had to ask why the removal was never committed.

**2026-07-21 · image readings.** Asserted readings of handwritten scoresheet
cells taken from image crops with verified-fact confidence during a model
comparison. Two cells scored as model errors were Claude's own misreadings.
Hedging held earlier in the session and dropped during the long comparison pass.

**2026-07-29 · search results.** Asserted a tournament's par score lived in an
embedded data blob "not the rendered markup", when Claude's own first search
that session had already returned the rendered element.

**2026-07-30 · probe output.** Three probe loops returned wrong results because
several commands resolved at the top level but not inside command substitution
within loops. Two false conclusions reached the user before the harness was
suspected: that every credential was "NOT FOUND", and every repository
"PRIVATE". A uniform verdict across every item in a probe loop is likelier a
broken harness than a finding.

## Cases where the rule did fire

The rule is not inert, which constrains what explanations are available. Any
proposed mechanism should account for why these went differently.

**2026-07-23 · configuration schema.** A question about an unfamiliar settings
block was answered by reading the schema out of the installed bundle rather than
from memory, which caught three distinct errors in the proposed snippet. The
memory-based answer would have been wrong three ways over.

**2026-07-28 · same session as a violation.** One claim — an editor's Python
interpreter discovery — was correctly flagged as unverified while a character
count in the same stretch was stated flat and was wrong. The entry's own
diagnosis: "what separated them was felt familiarity, not evidence."

**2026-07-29 · same session as a violation.** Most claims were hedged or
verified against captured pages; one slipped.
