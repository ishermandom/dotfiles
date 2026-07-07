#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Lands the current branch onto main while keeping main's history linear:
# rebases the branch onto main, then fast-forwards main to the branch tip.
# Every branch commit lands on main individually — landing never squashes.
# The rebase runs with --autosquash, so commits created with
# `git commit --fixup <commit>` are folded into their targets on the way.
#
# Run from the branch's checkout, typically a worktree. main must be checked
# out in another worktree (normally the primary checkout) so the
# fast-forward can update its working tree.
#
# On a rebase conflict the branch stops mid-rebase: resolve the conflicted
# files, `git add` them, run `git rebase --continue` (repeating if later
# commits also conflict), then rerun `git land` to finish — or run
# `git rebase --abort` to restore the branch.
#
# After landing, the branch tip and main tip are the same commit, so
# continued work on the branch simply proceeds from there.
#
# Usage: git land
#
# Exit codes: 0 = landed (or nothing to land); 1 = operational error,
# including rebase conflicts; 2 = usage error.

# $# is the argument count; the command takes none.
if [ $# -gt 0 ]; then
  echo "usage: git land" >&2
  exit 2
fi

# The branch to land is whatever HEAD points at; --quiet makes a detached
# HEAD yield empty output instead of an error message.
current_branch=$(git symbolic-ref --quiet --short HEAD)
if [ -z "$current_branch" ]; then
  echo "git land: HEAD is detached — run from the branch to land" >&2
  exit 1
fi
if [ "$current_branch" = "main" ]; then
  echo "git land: already on main — run from the branch to land" >&2
  exit 1
fi

# The rebase below needs a clean tree; checking first gives a clearer error
# than rebase's own refusal.
working_tree_status=$(git status --porcelain)
if [ -n "$working_tree_status" ]; then
  echo "git land: the working tree has uncommitted changes:" >&2
  echo "$working_tree_status" >&2
  exit 1
fi

# Find the checkout of main. --porcelain prints one block per worktree: a
# `worktree <path>` line followed by attribute lines such as
# `branch refs/heads/main`. Remember the most recent path; print it when the
# main-branch attribute appears. substr past the `worktree ` prefix keeps
# paths with spaces intact.
main_worktree=$(git worktree list --porcelain | awk '
  /^worktree / { path = substr($0, 10) }
  $0 == "branch refs/heads/main" { print path; exit }
')
if [ -z "$main_worktree" ]; then
  echo "git land: main is not checked out in any worktree — check out main" \
    "somewhere (or land from a worktree) so the fast-forward can update it" >&2
  exit 1
fi

# Replay the branch's commits atop main's tip — the step that keeps main
# linear; safe to rewrite because branches never push. --autosquash folds
# `fixup!` commits into their targets, and is a no-op when there are none.
git rebase --autosquash main
rebase_status=$?
if [ $rebase_status -ne 0 ]; then
  echo "git land: rebase onto main failed — resolve the conflicts and run" \
    "\`git rebase --continue\`, then rerun \`git land\` to finish; or run" \
    "\`git rebase --abort\`" >&2
  exit 1
fi

commit_count=$(git rev-list --count main.."$current_branch")
if [ "$commit_count" -eq 0 ]; then
  echo "git land: $current_branch has no commits beyond main —" \
    "nothing to land"
  exit 0
fi

# env -u drops the GIT_DIR pin that git exports when running a `!` alias —
# left set, it overrides -C's repo discovery and this merge would silently
# run against the branch's checkout instead (verified empirically).
# GIT_WORK_TREE overrides discovery the same way if the environment carries
# it. --ff-only cannot create a merge commit, so main's history stays linear
# by construction.
env -u GIT_DIR -u GIT_WORK_TREE \
  git -C "$main_worktree" merge --ff-only "$current_branch"
merge_status=$?
if [ $merge_status -ne 0 ]; then
  echo "git land: fast-forward of main to $current_branch failed" >&2
  exit 1
fi

echo "git land: landed $commit_count commits from $current_branch onto main"
