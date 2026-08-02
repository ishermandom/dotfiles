#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: run the project test suite. Stays silent while the
# suite passes; on failure it prints the output and exits non-zero, which
# `stop_checks.sh` turns into the message that halts the turn.
#
# Runs at Stop rather than PostToolUse (Write|Edit) so that multi-file edits
# that depend on each other aren't flagged mid-turn.
#
# The actual invocation is delegated to the quiet-tests wrapper so the
# canonical flags live in one place (~/.claude/scripts/quiet-tests.sh); its
# short-traceback setting keeps failure feedback token-lean here too.

# The hook inherits the session's current directory, which may sit below the
# repo root where run_tests.sh lives. quiet-tests.sh anchors on the repo root
# itself, so mirror its lookup rather than cd-ing here — this only has to
# decide whether the project has a suite at all. `:-` falls back to the current
# directory outside a git repo, as quiet-tests.sh does.
repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
project_root="${repo_root:-$PWD}"

# -x rather than -f: quiet-tests.sh refuses a run_tests.sh it cannot execute,
# which would reach the user as a test failure rather than a silent skip.
[ -x "$project_root/run_tests.sh" ] || exit 0

test_output=$(PYTEST_FROM_HOOK=1 "$HOME/.claude/scripts/quiet-tests.sh" 2>&1)
test_exit_code=$?

[ $test_exit_code -eq 0 ] && exit 0

echo "$test_output"
exit 1
