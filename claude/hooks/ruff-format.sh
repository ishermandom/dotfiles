#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Format and lint-fix all Python files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

format_dir() {
  local dir="$1"
  local has_python_files
  has_python_files=$(find "$dir" -name "*.py" -print -quit 2>/dev/null)
  [ -z "$has_python_files" ] && return 0

  # The ruff invocation is delegated to the quiet-ruff wrapper so the
  # canonical flags live in one place (~/.claude/scripts/quiet-ruff.sh).
  # 2>/dev/null discards stderr (e.g. "cannot parse file") so that ruff
  # warnings don't surface as hook errors; non-auto-fixable lint issues go
  # to stdout and don't block the stop (|| true).
  "$HOME/.claude/scripts/quiet-ruff.sh" "$dir" 2>/dev/null || true
}

format_dir .

# This script lives at claude/hooks/ruff-format.sh inside the dotfiles repo.
# Resolve its real path and walk up three levels to find the repo root, then
# format there too when the CWD is a different project.
script_real=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
dotfiles_root=$(dirname "$(dirname "$(dirname "$script_real")")")
if [ "$(realpath .)" != "$(realpath "$dotfiles_root")" ]; then
  format_dir "$dotfiles_root"
fi
