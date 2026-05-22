#!/usr/bin/env bash
# Format all Markdown, JavaScript, and TypeScript files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

# Hooks run with a minimal environment; Homebrew's bin directory may not be
# on PATH, so we add it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

has_formattable_files=$(find . \( -name "*.md" -o -name "*.js" -o -name "*.ts" \) -print -quit 2>/dev/null)
[ -z "$has_formattable_files" ] && exit 0

# Fall back to the global config when no project-level config exists.
config_args=()
if ! prettier --find-config-path "$PWD/placeholder" >/dev/null 2>&1; then
  config_args=(--config "$HOME/.prettierrc")
fi

prettier "${config_args[@]}" --write "**/*.md" "**/*.js" "**/*.ts" 2>/dev/null || true
