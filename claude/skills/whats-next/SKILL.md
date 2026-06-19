---
description:
  Propose what to work on next, then wait. Run when the user asks "what's next"
  or similar with no task in flight.
---

Drive the resume protocol: determine the single best next task, propose it, and
wait for approval. Work the steps in order.

## Steps

1. **Repo state first**: check `git status` and recent `git log` before the
   tracker. Uncommitted changes or unpushed work-in-progress mean the in-flight
   work is the real next item — surface it before proposing a tracker task.
   Reminder: You likely already have this in context.

2. **Read the tracker**: open the project's `tasks.md` (or plan doc) when
   present. With no tracker, base the proposal on repo state and recent commits,
   or say there is no tracker and ask the user what to work on.

3. **Pick the first actionable task** in execution order; skip blocked or
   deferred tasks, noting each in one line. If there are multiple resaonable
   next tasks, list up to ~3.

4. **Verify the task's premise** against the current code before proposing it —
   read or grep what the task claims needs changing. A task written sessions ago
   may be obsolete or already half-done.

5. **Propose, then wait**: a one-screen brief — last session's end point, the
   proposed task and why, any concerns — then wait for approval. Include repo
   state only when it demands action (uncommitted or unpushed work); a clean
   repo is padding, not information.
