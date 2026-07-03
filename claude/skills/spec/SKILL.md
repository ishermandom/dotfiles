---
description:
  Interview-led drafting or revision of a project spec. Run before queueing
  tasks for non-trivial work, or when the design changes.
---

Work through each step in order.

## 1. Orient

Check for an existing `spec.md` (and `README.md`) in the project. If a spec
exists, this is a revision: read it and ask the user what prompted the change
before anything else. Otherwise read enough of the project (README, entry
points) to ask informed questions rather than generic ones.

## 2. Interview

Gather requirements via `AskUserQuestion` — at most 4 questions per round,
grouped by theme, with concrete options drawn from the project rather than
abstract placeholders. Cover, over as many rounds as needed:

- Scope: what's in, what's explicitly out, what's deferred
- Hard parts: the riskiest or least-understood pieces
- Tradeoffs: where two designs compete, surface the choice
- Data and interfaces: models, formats, external surfaces
- Edge cases and failure behavior
- Testing strategy: what kind of verification fits

Keep the discussion open-ended until the approach is clear — don't compile while
load-bearing questions remain. For a revision, interview only the areas the
change touches.

## 3. Draft

Confirm the destination first: a `spec.md` file when design decisions need a
durable record; otherwise present the spec inline in chat. Either way, follow
the spec conventions: written for someone building or changing the project,
decisions recorded with their rationale, no status markers, enough captured that
the design could be re-derived from the document alone. Reference the README
rather than duplicating it; the README stays self-contained for users.

For a revision, edit the existing document — keep what still holds, and leave
sections the change doesn't touch alone.

## 4. Approve and hand off

Present the draft for approval — chunked, if it's long enough that working
through it at once would be uncomfortable. After approval, offer to queue the
implementation work in `tasks.md`: spec before tasks, per the default flow.
