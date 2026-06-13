# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

# Homebrew — sets PATH, MANPATH, INFOPATH. Works for both Intel and Apple
# Silicon by resolving the prefix at login time.
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

export EDITOR="emacs -nw"

# claude CLI
path+=("$HOME/.local/bin")

# Unlock and audit Claude Code's dedicated login keychain. See the sourced file
# for the one-time keychain setup it requires on a new machine.
source "$HOME/.claude-keychain.zsh"

# Redirect Playwright browser downloads to a shared path so all users can share
# one Chromium install instead of each user downloading their own copy.
export PLAYWRIGHT_BROWSERS_PATH=/Users/Shared/playwright

# Redirect Ollama model downloads to a shared path so all users share one set
# of model weights.
export OLLAMA_MODELS=/Users/Shared/ollama/models

# Private environment variables (not tracked in the public repo).
# Status: deprecated; currently no private environment variables to import.
#[[ -f "$HOME/.zprofile_private" ]] && source "$HOME/.zprofile_private"
