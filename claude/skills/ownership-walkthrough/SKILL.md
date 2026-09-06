---
description:
  Drive a post-hoc ownership review of completed work — self-review and fix,
  then present a risk-labeled map of the work for the user to review before
  committing. Run when a durable chunk of work is complete.
---

Work through each step in order, toward the ownership bar in
`CLAUDE.md #review-approach`.

Settle the scope as `~/.claude/docs/review-passes.md` #scope specifies.

## 1. Self-review and fix, to convergence

Clean the code before spending the user's attention on it. Run the review as
`~/.claude/skills/deep-review/SKILL.md` specifies: `deep-review` is
user-invocable only, so read that file and follow it rather than invoking the
skill.

When the work has no correctness concerns and needs only cleanup, run
`/simplify` over the code, and proofread the prose as
`~/.claude/skills/proofread/SKILL.md` specifies.

A finished review reports and stops there; this walkthrough continues at step 2.

## 2. Partition the work into logical units

Read the whole scope: the pending diff — staged, unstaged, and untracked
(`git status`, `git diff`, `git diff --staged`) — plus any commits the scope
covers (`git log`, `git show`). Group the changes into logical units, each a
single coherent concept — a "logical pull request" — regardless of file
boundaries. One unit may span several files; one file may hold several units.

## 3. Label each unit

For every unit, determine:

- **Risk tier** — `low`, `medium`, or `high`, by consequence: core logic, data
  handling, security-sensitive, or intricate code rates higher; mechanical,
  boilerplate, or cosmetic changes rate lower.
- **Recommended depth** — skim and ratify the decision for `low`; read closely
  for `medium`; line-by-line for `high`.
- **Why** — one line justifying the risk call.
- **Where to read** — the files and locations to open in the editor.

## 4. Propose the weight and present the map

Propose an overall weight — a quick skim for a small or low-risk change, a full
walkthrough for substantial or risky work — and let the user adjust. Present the
map as a compact list in chat: each unit with its description, risk tier,
recommended depth, why, and where to read. The user reads the actual code in
their editor or diff tool; chat carries only the map.

## 5. Walk through and resolve

Walk the units with the user at the recommended depth. Answer questions, explain
decisions and the alternatives weighed, and make any fixes the user asks for.
The walkthrough is done when the user owns the change.

## 6. Commit

Once the user is on board, commit whatever is still uncommitted. Commit
granularity and message conventions follow the global Git rules.
