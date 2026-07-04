---
paths:
  - "**/scratch/**"
---

# Prototyping bar

Files under `scratch/` carry a lighter quality bar than production — they are
exploratory spikes, feasibility probes, and design sketches, and the directory
is the durable marker of that intent.

While working under `scratch/`:

- **Style** — favor DAMP (repeat-for-clarity) over DRY; skip factoring polish.
  Clarity-in-the-moment beats durable structure at this bar.
- **Review** — no ownership walkthrough; committing within `scratch/` needs no
  review — the path already signals the bar.
- **Tests** — by default, write none and keep none green; probe correctness by
  hand.

**When the work graduates to production** — a cue like "let's build this
properly," or moving a file out of `scratch/` — raise it to the production bar
through the ownership review, as a clean reimplementation or a structured
walkthrough. That is the natural reassessment point.
