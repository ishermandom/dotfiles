#!/usr/bin/env bash
# Format all Markdown, JavaScript, and TypeScript files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

format_dir() {
  local dir="$1"

  # The prettier invocation (PATH setup, config fallback, file globs) is
  # delegated to the quiet-prettier wrapper so it lives in one place
  # (~/.claude/scripts/quiet-prettier.sh). Run from $dir so the wrapper's
  # globs are relative to it; formatting issues don't block the stop.
  (cd "$dir" && "$HOME/.claude/scripts/quiet-prettier.sh" >/dev/null 2>&1 || true)
}

format_dir .

# This script lives at claude/hooks/prettier-format.sh inside the dotfiles
# repo. Resolve its real path and walk up three levels to find the repo root,
# then format there too when the CWD is a different project.
script_real=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
dotfiles_root=$(dirname "$(dirname "$(dirname "$script_real")")")
if [ "$(realpath .)" != "$(realpath "$dotfiles_root")" ]; then
  format_dir "$dotfiles_root"
fi
