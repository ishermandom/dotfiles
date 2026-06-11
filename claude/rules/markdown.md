---
paths:
  - "**/*.md"
---

# Markdown style guide

## When writing any Markdown

Prettier auto-formats this file type. Write prose near 80 columns to minimize
rewrapping diffs.

- **Headings**: always use sentence case — capitalize only the first word and
  proper nouns.
- **Code**: always use fenced code blocks with a language tag. Use inline
  backticks for file paths, command names, and literal values.

## When writing spec documents

`spec.md` is for someone building or changing the project: requirements,
architecture decisions and their rationale, data models, edge cases, testing
strategy. `README.md` serves the complementary audience — someone using the
project — and stays fully self-contained; the spec may reference the README,
never the reverse.

- **No status**: never add progress markers or checkboxes to a spec; status
  lives in `tasks.md`.
- **Write for re-derivation**: capture enough that the design could be rebuilt
  or reviewed from the document alone.
- **Reference sources of truth**: when an operative detail lives and evolves
  elsewhere (code, configs, another doc), record the decision and its rationale
  and reference the source rather than mirroring its text — a mirror goes stale
  the moment the source changes.
- **Create the file** when design decisions need a durable record; otherwise
  keep the spec inline in conversation.

## When writing tasks documents

`tasks.md` is the per-project tracker — a multi-session work queue whose primary
job is to let work resume without re-reading everything. Optimize for
scannability and small diffs over time. Structure scales with need: a flat
checkbox list of to-dos suffices for most projects; introduce phases when work
needs sequencing, with a flat `## Backlog` section for unsequenced items.

The format conventions below keep trackers consistent across projects. How much
structure to use, what enters the tracker, and how aggressively to prune are
per-project judgments — keep the process light. Create the file when loose ends
start accumulating; single-session task breakdowns usually live in chat.

### When marking task status

Include this near the top of every tasks file:

```
Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped
```

Use per-task checkboxes. A status change is a one-character edit — don't lose
that property by encoding status elsewhere.

Always mark dropped tasks with `[-]` rather than deleting them. Add a brief
inline note explaining why; the decision shouldn't get lost.

### When organizing tasks

- **Phases**: group related tasks under `## Phase N — Name` headers. Separate
  phases with `---`. When all tasks in a phase are complete, append ` ✓` to the
  header.
- **Goal**: open each phase with a `**Goal:**` statement — one sentence that
  orients a reader without requiring them to read all the tasks.
- **Tasks**: one bullet per task, indented notes below as needed.

### When annotating a task

Annotate tasks with labeled notes when the reasoning or context isn't obvious.
Standard labels:

- `Rationale:` — why a decision was made
- `Open question:` — an unresolved choice that affects the task
- `Note:` — implementation detail, constraint, or context

Place notes directly under the relevant task or collect them in a subsection —
whichever keeps related content together. Include what Claude or the user
couldn't infer in a future session; omit the rest. For longer rationale, a
`### Notes` or `### Background` subsection under the phase header is cleaner
than deeply indented task bullets.

When a decision is settled in the spec, the note is a pointer — e.g.
`Note: settled — see spec.md (Session log).` — not a summary. A summary
duplicates the spec and drifts; keep only fragments the spec doesn't carry.

### When cross-referencing tasks

Prefer to omit task IDs. Add a `#slug` to a task only when another task needs to
reference it explicitly. Slugs are semantic (`#smoke-test`, not `1a`), so they
stay stable when tasks are reordered or inserted.

Cross-reference explicitly: "Depends on #slug" at the end of the task line or in
its notes. Implicit ordering (listing tasks in dependency order) is fine when no
cross-phase references are needed.

### When pruning completed work

Completed tasks and phases can be summarized or deleted once they stop informing
the remaining work — git preserves the detail. When in doubt, keep a dropped
task's rationale, a discovered constraint, or anything another task cites. A
file whose work is all done can simply be deleted.
