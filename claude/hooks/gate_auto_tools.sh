#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PreToolUse hook: deny bare invocations of the tools the Stop hook runs
# automatically (pytest, ruff, mypy, prettier), pointing intentional runs at
# the token-lean wrappers in ~/.claude/scripts/ instead. The wrappers don't
# match the pattern below, so they pass through this gate.
#
# Tool names count only in command position — not inside a string argument
# such as a commit message. Full accuracy would need a bash parser; deleting
# quoted strings and then normalizing command separators gets close enough.
#
# TODO: heredoc bodies are still scanned and can false-positive on lines that
# begin with a tool name.

bash_command=$(jq -r '.tool_input.command // ""')  # -r: raw string, strips JSON quotes

# Quote deletion must span newlines: grep anchors ^ at every line of a
# multi-line string, so a quoted commit message with a line that begins with
# a tool name would otherwise trip the gate. Hence perl (sed works line by
# line), with -0777 to read the whole input as one string.
delete_double_quoted='s/"(\\.|[^"\\])*"//gs'   # \\. steps over escaped chars
delete_single_quoted='s/\x27[^\x27]*\x27//gs'  # \x27 is a single-quote char
stripped=$(echo "$bash_command" |
  perl -0777 -pe "$delete_double_quoted; $delete_single_quoted")

# With quoted strings gone, normalize && and || to ; so the pattern below
# only needs ; and | as command separators.
normalized=$(echo "$stripped" | sed 's/&&/;/g; s/||/;/g')

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
