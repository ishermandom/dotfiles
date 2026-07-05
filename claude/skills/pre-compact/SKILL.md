---
description: >-
  Pre-compact durable-context check: write anything from this conversation that
  would otherwise be lost to the summary. Run right before issuing /compact.
disable-model-invocation: true
---

Work through each step, acting directly rather than narrating — write to files,
don't describe what you would write. Report nothing beyond a final one-line
status unless a step surfaces something that needs the user's decision (see step
2).

A compact keeps the session going but replaces the transcript with a summary, so
anything that exists only as conversation right now — and isn't yet written to a
file the next turn would consult — is what's at risk.

## 1. Durably record ambient context

Read `skills/session-context-routing.md` and run it in full.

A note on open questions specifically: a summary tends to flatten "still
deciding between A and B" into whichever side sounded more like a conclusion —
writing the fork down explicitly is what survives that flattening.

## 2. Report

Default output is a single word: `Ready`. Say more only when a step above left
something for the user to decide — a proposed new file, an ambiguous open
question, or anything else that needs a call before compacting — and keep that
to the minimum needed to act on it.
