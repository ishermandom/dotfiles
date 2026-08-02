#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: run mypy on the repo root, or on the current
# directory when outside a git repo. Stays silent while the types are clean; on
# errors it prints them and exits non-zero, which `stop_checks.sh` turns into
# the message that halts the turn.
#
# Runs at Stop (end of turn) rather than on each Edit so that multi-file changes
# that depend on each other aren't flagged mid-edit.
#
# Checks all Python files rather than only those edited this turn for two
# reasons: the Stop hook receives no information about which files changed, and
# a change to one file can break the types of callers in other files.
#
# The actual mypy invocation is delegated to the quiet-mypy runner so the
# canonical flags live in one place (~/.claude/scripts/quiet-mypy.sh).

# The hook inherits the session's current directory, which may sit in a
# subdirectory — where a change elsewhere in the repo is invisible, or, for an
# excluded directory (like a scratch/ dir), where mypy treats "every file
# excluded" as a hard error. Anchor to the repo root so the check spans the
# whole repo.
repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
[ -n "$repo_root" ] && cd "$repo_root"

# -print -quit stops find after the first match, for speed.
has_python_files=$(find . -name "*.py" -print -quit 2> /dev/null)
[ -z "$has_python_files" ] && exit 0

mypy_output=$("$HOME/.claude/scripts/quiet-mypy.sh" 2>&1)
mypy_exit_code=$?

[ $mypy_exit_code -eq 0 ] && exit 0

echo "$mypy_output"
exit 1
