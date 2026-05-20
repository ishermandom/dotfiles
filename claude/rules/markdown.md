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

## When writing plan documents

Plan documents are multi-session work queues. Their primary job is to let work
resume without re-reading everything. Optimize for scannability and small diffs
over time.

### When marking task status

Include this near the top of every plan:

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

### When cross-referencing tasks

Prefer to omit task IDs. Add a `#slug` to a task only when another task needs to
reference it explicitly. Slugs are semantic (`#smoke-test`, not `1a`), so they
stay stable when tasks are reordered or inserted.

Cross-reference explicitly: "Depends on #slug" at the end of the task line or in
its notes. Implicit ordering (listing tasks in dependency order) is fine when no
cross-phase references are needed.
