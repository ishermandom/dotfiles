#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PostToolUse / PostToolUseFailure hook: when Claude runs one of the quiet check
# runners (~/.claude/scripts/quiet-*.sh), surface their output to the user as a
# system message so manual check runs are never invisible.

input=$(cat)
command=$(jq -r '.tool_input.command // ""' <<< "$input")

# Only surface output for the quiet check runners.
if [[ "$command" != *"scripts/quiet-"* ]]; then
  exit 0
fi

stdout=$(jq -r '.tool_response.stdout // ""' <<< "$input")
stderr=$(jq -r '.tool_response.stderr // ""' <<< "$input")
output="${stdout}${stderr}"
[ -z "$output" ] && exit 0

jq -n --arg msg "$output" '{"systemMessage": $msg}'
