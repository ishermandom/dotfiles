#!/usr/bin/env bash
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

  # 2>/dev/null discards stderr (e.g. "cannot parse file") so that ruff
  # warnings don't surface as hook errors. The main case where ruff errors —
  # unparseable files — is already caught by mypy. Non-auto-fixable lint
  # issues go to stdout and are unaffected. Unexpected ruff crashes would be
  # silently missed, but that is unlikely in practice.
  ruff check --fix "$dir" 2>/dev/null
  ruff format "$dir" 2>/dev/null
}

format_dir .

# ~/.claude may symlink into a dotfiles repo outside the CWD. Format there
# too so that edits made via the symlink path are caught by this hook.
claude_real=$(readlink -f ~/.claude 2>/dev/null)
if [ -n "$claude_real" ]; then
  dotfiles_root=$(dirname "$claude_real")
  if [ "$(realpath .)" != "$(realpath "$dotfiles_root")" ]; then
    format_dir "$dotfiles_root"
  fi
fi
