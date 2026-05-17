#!/usr/bin/env bash
# Format all Markdown files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

# Hooks run with a minimal environment; Homebrew's bin directory may not be
# on PATH, so we add it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

has_markdown_files=$(find . -name "*.md" -quit 2>/dev/null)
[ -z "$has_markdown_files" ] && exit 0

prettier --write "**/*.md" 2>/dev/null || true
