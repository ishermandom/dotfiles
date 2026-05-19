#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# InstructionsLoaded hook: logs whether the python.md rule was loaded.
# Output goes to ~/.claude/logs/instructions-loaded.log.

log_dir=~/.claude/logs
log_file="$log_dir/instructions-loaded.log"
mkdir -p "$log_dir"

input=$(cat)  # read full event JSON from stdin
timestamp=$(date -u +%FT%TZ)

echo "[$timestamp]" >> "$log_file"
echo "$input" | jq '.' >> "$log_file"
echo "" >> "$log_file"
