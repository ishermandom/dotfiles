#!/usr/bin/env bash
# Format all Markdown, JavaScript, and TypeScript files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

# Hooks run with a minimal environment; Homebrew's bin directory may not be
# on PATH, so we add it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

format_dir() {
  local dir="$1"
  local has_formattable_files
  has_formattable_files=$(find "$dir" \( -name "*.md" -o -name "*.js" -o -name "*.ts" \) -print -quit 2>/dev/null)
  [ -z "$has_formattable_files" ] && return 0

  # Fall back to the global config when no project-level config exists.
  local config_args=()
  if ! prettier --find-config-path "$dir/placeholder" >/dev/null 2>&1; then
    config_args=(--config "$HOME/.prettierrc")
  fi

  # Run from $dir so that prettier's glob expansion is relative to it.
  (cd "$dir" && prettier "${config_args[@]}" --write "**/*.md" "**/*.js" "**/*.ts" 2>/dev/null || true)
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
