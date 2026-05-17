#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PreToolUse hook: prompt before running any tool that the Stop hook runs
# automatically (pytest, ruff, mypy, prettier). Surfaces a permission prompt
# so intentional runs can be approved while reflexive ones are denied.

bash_command=$(jq -r '.tool_input.command // ""')  # -r: raw string, strips JSON quotes

# Normalize && and || to ; so the pattern only needs to handle ; and |
# as command separators. This lets us match tool names only at a command
# boundary, not when they appear as string arguments (e.g. in -m "...pytest...").
normalized=$(echo "$bash_command" | sed 's/&&/;/g; s/||/;/g')

cmd_start='(^|[;|])[[:space:]]*'  # start of string or after a separator
auto_tools='(pytest|python -m pytest|ruff|mypy|prettier)'
word_end='([[:space:]]|$)'
pattern="${cmd_start}${auto_tools}${word_end}"

if echo "$normalized" | grep -qE "$pattern"; then  # -q: exit code only; -E: extended regex
  echo '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "pytest, ruff, mypy, and prettier run automatically at Stop — running them mid-turn risks false results while edits are still in flight. If this was reflexive, stop here. If intentional (a specific diagnostic reason, e.g. running mypy on one file to understand an error), tell the user what you want to run and why, and ask them to run it with ! <command>."
    }
  }'
fi
