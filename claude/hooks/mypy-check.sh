#!/usr/bin/env bash
# Run mypy on the current directory and block Claude's stop turn if errors
# are found, feeding the output back as context.
#
# Runs on Stop (end of turn) rather than on each Edit so that multi-file
# changes that depend on each other aren't flagged mid-edit.
#
# Checks all Python files rather than only those edited this turn for two
# reasons: the Stop hook receives no information about which files changed,
# and a change to one file can break the types of callers in other files.

# -print -quit stops find after the first match, for speed.
has_python_files=$(find . -name "*.py" -print -quit 2>/dev/null)
[ -z "$has_python_files" ] && exit 0

mypy_output=$(mypy --strict . 2>&1)
mypy_exit_code=$?

[ $mypy_exit_code -eq 0 ] && exit 0

# jq -Rs reads all of stdin as a single raw string (-R) and encodes it as a
# JSON string (-s joins lines). This safely escapes quotes, newlines, etc.
json_encoded_output=$(printf '%s' "$mypy_output" | jq -Rs .)

printf '{"continue":false,"stopReason":%s}' "$json_encoded_output"
