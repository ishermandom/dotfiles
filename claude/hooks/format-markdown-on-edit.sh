#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Format a just-edited Markdown file (PostToolUse on Edit|Write).
#
# Formatting at edit time keeps the on-disk text identical to what Claude
# believes it wrote: the harness shows the formatter's rewraps to Claude
# immediately, so follow-up Edits anchor to the post-format wording instead
# of failing against text prettier has since rewrapped. The Stop-time
# prettier pass still runs as a safety net for files changed by other means.

# The hook payload arrives as JSON on stdin; both Edit and Write put the
# touched file at .tool_input.file_path. `-r` emits the raw string without
# JSON quotes; `// empty` maps null/missing to empty output.
file_path=$(jq -r '.tool_input.file_path // empty')

# Only Markdown needs edit-time formatting; other file types are covered at
# Stop. Deleted or renamed-away files have nothing to format.
case "$file_path" in
  *.md) ;;
  *) exit 0 ;;
esac
[ -f "$file_path" ] || exit 0

output=$("$HOME/.claude/scripts/quiet-prettier.sh" "$file_path" 2>&1)
status=$?

# Exit 2 routes stderr back to Claude: a prettier failure here means the
# Markdown just written is malformed and worth fixing now.
if [ $status -ne 0 ]; then
  echo "$output" >&2
  exit 2
fi
exit 0
