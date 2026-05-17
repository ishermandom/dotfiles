---
description: End-of-session protocol. Run when wrapping up a session.
---

Work through each step in order.

## 1. Session naming

Evaluate whether this session is worth naming. Suggest `/rename <name>` only
for sessions with incomplete work or context worth returning to. Skip for
one-offs and fully completed tasks — most sessions don't need a name.

## 2. Upskilling

Suggest one or two concrete takeaways for the user to consider — something
observed about the codebase, tooling, or a better approach. Skip if nothing
stands out.

## 3. Handoff note

Compile a draft with these sections:

- **Accomplished** — what was completed
- **Decisions** — key choices and their rationale
- **Files Modified** — changed files
- **Next Steps** — immediate next work items
- **Avoid** — approaches tried and abandoned, with why
- **Reflection** — token and attention efficiency: where did tokens go, was
  context well-focused on the right things, what would have been faster?
  (2–3 bullets)

Propose the entry as an Edit to `.claude/handoff.md` directly (prepended,
entries separated by `---`). Using the Edit tool makes the change visible and
harder to accidentally drop than text in chat.

## 4. Learning

Update memory files with anything worth persisting: corrections, preferences,
project facts. If a `~/.claude/docs/` file needs updating, flag it and ask
before editing.

## 5. Reviewer session

If production code was written, offer:
> "Consider a reviewer session: open a fresh session with the relevant files in
> context and run `/review`."
