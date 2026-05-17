#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PreToolUse hook: prompt before running any tool that the Stop hook runs
# automatically (pytest, ruff, mypy, prettier). Surfaces a permission prompt
# so intentional runs can be approved while reflexive ones are denied.

bash_command=$(jq -r '.tool_input.command // ""')  # -r: raw string, strips JSON quotes

word_boundary_before='(^|[[:space:]])'
auto_tools='(pytest|python -m pytest|ruff|mypy|prettier)'
word_boundary_after='([[:space:]]|$)'
pattern="${word_boundary_before}${auto_tools}${word_boundary_after}"

if echo "$bash_command" | grep -qE "$pattern"; then  # -q: exit code only; -E: extended regex
  echo '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "pytest, ruff, mypy, and prettier run automatically at Stop — running them mid-turn risks false results while edits are still in flight. If this was reflexive, stop here. If intentional (a specific diagnostic reason, e.g. running mypy on one file to understand an error), tell the user what you want to run and why, and ask them to run it with ! <command>."
    }
  }'
fi
