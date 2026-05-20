---
paths:
  - "**/*.md"
---

# Markdown style guide

## General

Prettier auto-formats this file type. Write prose near 80 columns to minimize
rewrapping diffs.

- **Headings**: sentence case — capitalize only the first word and proper nouns.
- **Code**: fenced code blocks with a language tag. Inline backticks for file
  paths, command names, and literal values.

## Plan documents

Plan documents are multi-session work queues. Their primary job is to let work
resume without re-reading everything. Optimize for scannability and small diffs
over time.

### Status legend

Include this near the top of every plan:

```
Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped
```

Use per-task checkboxes. A status change is a one-character edit — don't lose
that property by encoding status elsewhere.

Mark dropped tasks with `[-]` rather than deleting them. Add a brief inline note
explaining why; the decision shouldn't get lost.

### Structure

- **Phases**: group related tasks under `## Phase N — Name` headers. Separate
  phases with `---`. When all tasks in a phase are complete, append ` ✓` to the
  header.
- **Goal**: open each phase with a `**Goal:**` statement — one sentence that
  orients a reader without requiring them to read all the tasks.
- **Tasks**: one bullet per task, indented notes below as needed.

### Rationale, notes, and open questions

Annotate tasks with labeled notes when the reasoning or context isn't obvious.
Standard labels:

- `Rationale:` — why a decision was made
- `Open question:` — an unresolved choice that affects the task
- `Note:` — implementation detail, constraint, or context

Place notes directly under the relevant task or collect them in a subsection —
whichever keeps related content together. Include what a future reader couldn't
infer; omit the rest. For longer rationale, a `### Notes` or `### Background`
subsection under the phase header is cleaner than deeply indented task bullets.

### Task IDs

Omit task IDs by default. Add a `#slug` to a task only when another task needs
to reference it explicitly. Slugs are semantic (`#smoke-test`, not `1a`), so
they stay stable when tasks are reordered or inserted.

Cross-reference explicitly: "Depends on #slug" at the end of the task line or in
its notes. Implicit ordering (listing tasks in dependency order) is fine when no
cross-phase references are needed.
