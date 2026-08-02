#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Format all Markdown, JavaScript, and TypeScript files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

format_dir() {
  local dir="$1"
  local prettier_wrapper="$HOME/.claude/scripts/quiet-prettier.sh"

  # The prettier invocation (PATH setup, config fallback, file globs) is
  # delegated to the wrapper so it lives in one place. Run from $dir so the
  # wrapper's globs are relative to it; formatting issues don't block the stop.
  (cd "$dir" && "$prettier_wrapper" > /dev/null 2>&1 || true)
}

format_dir .

# This script lives at claude/hooks/prettier-format.sh inside the dotfiles
# repo. Resolve its real path and walk up three levels to find the repo root,
# then format there too when the session is working in a different project.
script_real=$(readlink -f "${BASH_SOURCE[0]}" 2> /dev/null)
dotfiles_root=$(realpath "$(dirname "$(dirname "$(dirname "$script_real")")")")
current_dir=$(realpath .)

# The root itself and every worktree beneath it are already covered by the
# format above, so only a genuinely different project needs the second pass.
# Matching on the trailing slash keeps a sibling such as dotfiles-backup out.
is_inside_dotfiles=""
case "$current_dir" in
  "$dotfiles_root" | "$dotfiles_root"/*) is_inside_dotfiles="yes" ;;
esac

if [ -z "$is_inside_dotfiles" ]; then
  format_dir "$dotfiles_root"
fi
