#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PreToolUse hook: deny bare invocations of the tools the Stop hook runs
# automatically (pytest, ruff, mypy, prettier), pointing intentional runs at
# the token-lean wrappers in ~/.claude/scripts/ instead. The wrappers don't
# match the pattern below, so they pass through this gate.

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
      "permissionDecisionReason": "pytest, ruff, mypy, and prettier run automatically at Stop — do not re-run them reflexively mid-turn. If this run adds value (e.g. confirming an intermediate state lets more work land this turn), use the token-lean wrappers instead: ~/.claude/scripts/quiet-{tests,mypy,ruff,prettier}.sh [paths]. Their output is shown to the user automatically."
    }
  }'
fi
