# Handoff and Session Log Format

Two complementary files written at session end by `skills/wrap-session`:

- **`.claude/handoff.md`** (project-local) — resumption state: what the next
  session needs to start immediately. Prepend-only; entries separated by `---`.
- **`.claude/session-log.md`** (project-local) — historical record: what
  happened this session. Append-only; entries separated by `---`.

---

## Handoff format

Timestamp header followed by up to four sections. Omit any section with no
content.

```
# YYYY-MM-DD — <one-line session description>

## Next Steps
- <task>: <enough context to start without reading anything else; as tight as
  the content allows>
- ...

## In Progress
- <item>: <intended approach, so the next session doesn't re-derive it from
  partial work>

## Open Decisions
- <unresolved choice and what it blocks>

## Context
- <non-obvious fact discovered this session that's needed for upcoming work>
- ...
```

**What each section is for:**

- **Next Steps** — tasks in priority order. Each entry is self-contained:
  include just enough context to start without additional reading. Keep it as
  tight as the content allows — a phrase when that suffices, more when it
  doesn't.
- **In Progress** — work started but not finished (partial implementations,
  uncommitted changes). Note the intended approach so re-reading partial work
  isn't necessary.
- **Open Decisions** — unresolved choices that affect upcoming work. Not
  settled decisions (those go in the session log).
- **Context** — forward-useful knowledge that would be expensive to re-derive:
  design rationale not captured in the plan, non-obvious task dependencies,
  discovered file locations or tool behaviors. Not history — only include if
  the next session will actually need it.

---

## Session log format

TBD: Will be defined in Phase 2b. Fields: Accomplished, Decisions, Files Modified, Avoid, Reflection.
