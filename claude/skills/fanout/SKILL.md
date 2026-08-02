---
description:
  Start a background session per tracker task, each in its own git worktree.
disable-model-invocation: true
---

Start one background Claude Code session per task the user has chosen, each
working in its own git worktree. Work the steps in order.

## Steps

1. **Take the task set from the user**: which tasks to fan out is the user's
   call. Ask for clarification when a choice is ambiguous or when tasks are
   coupled — when either task's correct answer depends on how the other turns
   out. Coupling usually takes one of two shapes: one task needs work that isn't
   done yet, or two tasks would settle the same open question — which convention
   to adopt, which helper to introduce, where a new rule lives. Coupled tasks go
   in consecutive fanouts, the first landing before the second starts. Two tasks
   that merely edit the same file are fine as concurrent lanes; the conflict is
   ordinary work at landing.

2. **Check what the worktrees will branch from**: with `worktree.baseRef` unset,
   a new worktree starts from `origin/main`, so unpushed commits and uncommitted
   changes never reach it. If there is a gap, report it and ask how to proceed
   rather than launching agents onto a stale base.

3. **Record each task's worktree in the tracker before launching anything**: add
   a single `Worktree: <slug>` line under the task, naming the worktree for the
   work it holds — `zed-prettier`, not `task-2`. The line keeps the in-flight
   state from getting lost and says where to pick the work back up; writing it
   first also gives the launch prompt a unique way to name the task. Commit and
   push this change to the task tracker. Treat the /fanout skill invocation as
   explicit user permission for this scoped commit and push.

4. **Launch one background session per task** from the main checkout:

   ```bash
   claude --bg --model claude-opus-5 --effort xhigh --permission-mode auto \
     --append-system-prompt-file ~/.claude/skills/fanout/agent-prompt.md \
     "In worktree <slug>, work the tasks.md task annotated Worktree: <slug>."
   ```

   Add no other flags by default — CLAUDE.md governs the rest of an agent's
   behavior.

   For a task changing hooks, `settings.json`, or anything else reached through
   `~/.claude`, say so in the prompt: those paths symlink to the main checkout,
   so an agent can otherwise mistake its worktree's config for the one its own
   session runs. `rules/claude-configuration.md` #worktree-live-validation
   covers firing the worktree's copy safely.
