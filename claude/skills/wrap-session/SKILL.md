---
description: End-of-session protocol. Run when wrapping up a session.
---

Work through each step in order.

## 1. Session naming

Evaluate whether this session is worth naming. Suggest `/rename <name>` only for
sessions with incomplete work or context worth returning to. Skip for one-offs
and fully completed tasks — most sessions don't need a name.

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
- **Reflection** — two dimensions:
  - _Token efficiency_: estimate the session's main token costs (file reads:
    `wc -c` on files read, ~chars/4 for tokens; subagent output: estimate from
    content length; other large tool results). Identify at least one concrete
    case of higher-than-necessary consumption with a diagnosis (_why_ did this
    happen?) and a mechanism (_what specifically changes_ to prevent it?).
  - _Attention efficiency_: was context well-focused on the right things? Were
    there tangents, unnecessary back-and-forth, or work that could have been
    deferred? Each identified failure needs a diagnosis and mechanism specific
    enough that a skeptic couldn't dismiss them as obvious. "Do better next
    time" is a wish, not a reflection. Aim for 2–3 bullets total, but use as
    many or few as the session warrants.

Propose the entry as an Edit to `.claude/handoff.md` directly (prepended,
entries separated by `---`). Using the Edit tool makes the change visible and
harder to accidentally drop than text in chat. The Edit tool requires a prior
Read, but only read the first 3–5 lines (`limit: 5`) — enough to get the header
as an anchor string. Never read the full file; the existing entries are
irrelevant for prepending.

## 4. Pending commits

If in a git repo, run `git status`. If there are uncommitted changes, remind the
user to commit before closing the session.

## 5. Learning

Update memory files with anything worth persisting: corrections, preferences,
project facts. If a `~/.claude/docs/` file needs updating, flag it and ask
before editing.

## 5. Reviewer session

If production code was written, offer:

> "Consider a reviewer session: open a fresh session with the relevant files in
> context and run `/review`."
