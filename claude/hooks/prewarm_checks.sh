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
# Formatting is left to the Stop hook, since it rewrites files the session may
# be editing meanwhile. Here prettier only checks the files. A check rewrites
# nothing, and it fills prettier's cache, so the Stop hook's prettier skips
# every file the check found formatted. Prettier is the one formatter worth
# warming: in the Stop hook, ruff runs beside it and finishes first even from a
# cold cache.
#
# Prettier's cache keys each file on its contents, so an edit made after the
# check is formatted as usual. One narrow gap remains: prettier reads a file
# once to check it and again to cache it, milliseconds later. When an edit lands
# between the two reads, the edited contents are cached as formatted without
# ever being checked, and the file stays unformatted until it next changes.
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

# Prettier's check and the checks below build nothing for each other, so the
# check runs alongside them rather than holding them up. The trailing `&` runs
# it in the background, and `$!` holds its process ID for the `wait` at the end.
"$hooks_dir/../scripts/quiet-prettier.sh" --check > /dev/null 2>&1 &
prettier_pid=$!

# The same checks, in the same order, as stop_checks.sh. Each runs even when the
# one before it fails: a failure is the Stop hook's to report, and every check's
# caches are worth building regardless.
for check in mypy-check.sh run_tests.sh ruff-lint.sh clippy-lint.sh \
  shellcheck-lint.sh; do
  "$hooks_dir/$check" > /dev/null 2>&1
done
wait "$prettier_pid"
