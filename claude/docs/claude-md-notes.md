# CLAUDE.md maintainer notes

Editing-time rationale for CLAUDE.md rules — the "why" a future editor needs
that a running session does not. The parallel of a skill's companion `notes.md`:
never loaded at runtime, read when editing CLAUDE.md. The file exists because
CLAUDE.md injection does not strip HTML comments (verified 2026-07-03), so
rationale cannot ride in the file for free; anything beyond a one-clause inline
why lands here, keyed by rule.

## Pronouns and demonstratives (CLAUDE.md `#pronouns`)

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

## License (CLAUDE.md `#license`)

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

## Prefer Edit over Write (CLAUDE.md `#prefer-edit`)

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

## Prefer to search code with rg (CLAUDE.md `#prefer-rg`)

The inline clause carries the misfire risk (BRE mode). The fuller picture: the
`grep` shim runs ugrep with `-G`, so `|`, `+`, `(` are literal without `-E`; rg
defaults to recursive, smart-case, gitignore-aware search with an ERE-ish flavor
that matches how patterns are typically written.
