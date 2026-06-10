---
description: End-of-session protocol. Run when wrapping up a session.
---

Work through each step in order.

## 1. Session naming

Evaluate whether this session is worth naming. Suggest `/rename <name>` only for
sessions with incomplete work or context worth returning to. Skip for one-offs
and fully completed tasks — most sessions don't need a name.

## 2. Upskilling

Help the user use Claude Code and their other tools more effectively over time.
In chat, surface anything observed this session that they could be doing more
effectively:

- A product feature that would have helped (a Claude Code capability, flag,
  slash command, hook, or skill they aren't using)
- An efficiency tip — a faster or lower-friction way to do something they did
  manually or repeatedly
- An interesting pattern that came up that's worth remembering or internalizing

Suggest one or two takeaways, concretely tied to moments from this session.
This is chat-only guidance for the user to internalize — don't persist it
anywhere. Skip if nothing stands out.

## 3. Durable context routing

Identify what a future session would need from this one, and write each piece
into the durable file where that session would look for it. Do not write a
session log: narrative belongs in git history and chat, and a log entry is where
context goes to get stale.

- **Pending work, next steps, and decisions about them** → the project's
  `tasks.md` (or plan doc): update statuses, add tasks, and attach
  `Rationale:`/`Note:` annotations per the plan-document rules.
- **Approaches tried and abandoned** → a `Note:` on the relevant task, or a
  `[-]` dropped task, so the dead end isn't retried.
- **Findings or constraints that outlive any one task** → the project file a
  reader would consult for that topic (e.g. a Findings section, README, spec).
- **Accomplished work and files modified** → nowhere: commit messages and git
  history already record these.

If a piece of durable context fits none of the project's existing durable files,
propose a new file — name and scope — and confirm both with the user before
creating it.

## 4. Reflection

Present in chat, across two dimensions:

- _Token efficiency_: estimate the session's main token costs (file reads:
  `wc -c` on files read, ~chars/4 for tokens; subagent output: estimate from
  content length; other large tool results). Identify at least one concrete case
  of higher-than-necessary consumption with a diagnosis (_why_ did this happen?)
  and a mechanism (_what specifically changes_ to prevent it?).
- _Attention efficiency_: was context well-focused on the right things? Were
  there tangents, unnecessary back-and-forth, or work that could have been
  deferred? Each identified failure needs a diagnosis and mechanism specific
  enough that a skeptic couldn't dismiss them as obvious. "Do better next time"
  is a wish, not a reflection. Aim for 2–3 bullets total, but use as many or few
  as the session warrants.

A mechanism that generalizes beyond this session belongs in memory or the
relevant rules file — handle that in the Learning step.

## 5. Pending commits

If in a git repo, run `git status`. If there are uncommitted changes, remind the
user to commit before closing the session.

## 6. Learning

Update memory files with anything worth persisting: corrections, preferences,
project facts. If a `~/.claude/docs/` file needs updating, flag it and ask
before editing.

## 7. Reviewer session

If production code was written, offer:

> "Consider a reviewer session: open a fresh session with the relevant files in
> context and run `/review`."
