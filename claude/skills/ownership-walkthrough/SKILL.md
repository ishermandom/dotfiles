---
description:
  Drive a post-hoc ownership review of completed work — self-review and fix,
  then present a risk-labeled map of the pending diff for the user to review
  before committing. Run when a durable chunk of work is complete.
---

Work through each step in order. The aim is the user's ownership of what lands —
by default every line maintainable by the user solo, at minimum the key
decisions ratified — settled before anything is committed.

## 1. Self-review and fix

Clean the code before spending the user's attention on it. Run
`/code-review --fix` over the pending changes, effort scaled to risk — `low` or
`medium` for routine work, higher for core logic, data handling, or
security-sensitive code. Use `/simplify` instead when there are no correctness
concerns, only cleanup. Never use the `ultra` effort here — it runs in the cloud
and is outside this local flow.

## 2. Partition the diff into logical units

Read the full pending diff — staged, unstaged, and untracked (`git status`,
`git diff`, `git diff --staged`). Group the changes into logical units, each a
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

Once the user is on board, commit — review precedes the commit, so history stays
clean. Commit granularity and message conventions follow the global Git rules.
