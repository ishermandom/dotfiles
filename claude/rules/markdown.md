---
paths:
  - "**/*.md"
---

# Markdown style guide

## When writing any Markdown

Prettier formats this file type automatically right after each Edit or Write
(and again at Stop, as a safety net). Rewraps arrive as file-modification
notices. After any such notice for a file this turn, re-read the target region
before composing an `old_string` — match the post-format wording, not your
pre-format snapshot.

- **Headings**: always use sentence case — capitalize only the first word and
  proper nouns.
- **Section labels match their content precisely**: a label broader than its
  section misleads. Narrow the label before broadening the section.
- **Code**: always use fenced code blocks with a language tag. Use inline
  backticks for file paths, command names, and literal values.
- **Nested list items**: indent a child bullet 2 spaces, aligned with the
  parent's `-` marker, never to the text after a `- [ ] ` checkbox — a child
  indented to the checkbox text gets folded into the parent paragraph by
  Prettier, silently destroying the sublist.

<!-- Nested list items: a `-` item's CommonMark content column is 2 (after the
marker); the `[ ]` is content, not marker, so it does not shift nesting out to
column 6. At 6 spaces with no blank line the child parses as a lazy paragraph
continuation, which Prettier then renders inline. Verified empirically. -->

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

### When resuming work from a tasks file

At the start of a session, the `whats-next` skill drives this — see it for the
resume protocol.

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

- **Phases**: group related tasks under short named headers (`## Auth cleanup`)
  — no phase numbers; names and `#slug`s identify work and stay meaningful as
  phases are reordered or pruned. Separate phases with `---`. When all tasks in
  a phase are complete, append ` ✓` to the header.
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

**Prune at completion by default.** When you mark a task `[x]`, in the same edit
delete it instead if its detail is preserved elsewhere (the commit, the code, or
a follow-up task) and it no longer informs remaining work. Keep an `[x]` entry
only when its done-state still informs _in-progress_ work this session — e.g. an
unfinished task depends on it. The same test applies to what you write, not just
what you keep: a fiddly implementation detail (what was tried and rejected, a
workaround's specifics) already lives in the code or commit message, so skip
writing a task note for it rather than pruning one later. Reserve `spec.md` for
a genuine architecture or design decision — write it there once, not into a task
note. Don't let completed checkboxes accumulate for a later cleanup pass.

Completed and dropped tasks, and whole completed phases, can be summarized or
deleted once they stop informing the remaining work — git preserves the detail.
Default to **deleting**, not summarizing: reach for a summary only when
something concrete would otherwise be lost with no other record (not recoverable
from the code, the commit, or `spec.md`). A summary that just restates what
`spec.md` already carries, or a note that references a "plan" no longer stated
anywhere in the file, is worth less than deleting it. The `[-]` rule above
governs drop time, not pruning. When in doubt, keep a dropped task's rationale,
a discovered constraint, or anything another task cites. A file whose work is
all done can simply be deleted.
