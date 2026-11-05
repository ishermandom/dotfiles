#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PostToolUse hook on EnterWorktree: run the Stop hook's checks once, in the
# background, as soon as a session enters a worktree.
#
# A fresh worktree holds none of what the checks build for themselves — the
# project's virtual environment, mypy's cache, installed packages, compiled
# tests — so the first Stop there would build all of it while the turn waits to
# end. Started here, that work overlaps the rest of the turn instead. The hook
# is registered `async`, so entering the worktree never waits on it.
#
# Formatting is left out. It rewrites files, and this runs while the session may
# be editing them; the Stop hook formats as usual.
#
# A Stop, or a check Claude runs mid-turn, may start before this finishes, and
# then runs alongside it. Repeating the same work at once is harmless, with one
# exception: two installs into one directory can break each other. uv and Cargo
# lock their own directories; any other install step in a project's run_tests.sh
# has to take a lock of its own.

# ${BASH_SOURCE[0]} is this script's own path, and -f resolves it through the
# ~/.claude symlink, so the steps are read from the dotfiles repo.
hooks_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Claude Code passes the hook's input as JSON on stdin, and its `cwd` is the
# root of the worktree just entered.
worktree=$(jq -r '.cwd')
cd "$worktree" || exit 1

# The checks never run in someone else's checkout (stop_checks.sh says why), so
# there is nothing to prewarm there.
"$hooks_dir/is-third-party-repo.sh" "$PWD" && exit 0

# The same checks, in the same order, as stop_checks.sh. Each runs even when the
# one before it fails: a failure is the Stop hook's to report, and every check's
# caches are worth building regardless.
for check in mypy-check.sh run_tests.sh ruff-lint.sh clippy-lint.sh; do
  "$hooks_dir/$check" > /dev/null 2>&1
done
