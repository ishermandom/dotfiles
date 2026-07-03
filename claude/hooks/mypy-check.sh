#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Run mypy on the current directory when Claude tries to stop. On errors,
# halt the stop and show the output to the user; Claude sees it alongside
# the user's next message and fixes from there. Deliberately not a
# decision:block auto-re-invoke: a block can spin forever when Claude cannot
# fix the failure, guarding against that is out of scope for now, and the
# workaround is trivial — the user prods the next turn and the fix proceeds.
#
# Runs on Stop (end of turn) rather than on each Edit so that multi-file
# changes that depend on each other aren't flagged mid-edit.
#
# Checks all Python files rather than only those edited this turn for two
# reasons: the Stop hook receives no information about which files changed,
# and a change to one file can break the types of callers in other files.
#
# The actual mypy invocation is delegated to the quiet-mypy wrapper so the
# canonical flags live in one place (~/.claude/scripts/quiet-mypy.sh).

# -print -quit stops find after the first match, for speed.
has_python_files=$(find . -name "*.py" -print -quit 2>/dev/null)
[ -z "$has_python_files" ] && exit 0

mypy_output=$("$HOME/.claude/scripts/quiet-mypy.sh" 2>&1)
mypy_exit_code=$?

[ $mypy_exit_code -eq 0 ] && exit 0

# jq -Rs reads all of stdin as a single raw string (-R) and encodes it as a
# JSON string (-s joins lines). This safely escapes quotes, newlines, etc.
json_encoded_output=$(printf '%s' "$mypy_output" | jq -Rs .)

printf '{"continue":false,"stopReason":%s}' "$json_encoded_output"
