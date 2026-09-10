# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

# Homebrew — sets PATH, MANPATH, INFOPATH. Works for both Intel and Apple
# Silicon by resolving the prefix at login time.
eval "$(/opt/homebrew/bin/brew shellenv 2> /dev/null \
  || /usr/local/bin/brew shellenv)"

export EDITOR="emacs -nw"

# claude CLI
path+=("$HOME/.local/bin")

# Unlock and audit Claude Code's dedicated login keychain. See the sourced file
# for the one-time keychain setup it requires on a new machine.
source "$HOME/.claude-keychain.zsh"

# Warn if the home directory allows world access. macOS sets 755 by default,
# which lets any local user list and traverse into ~.
_home_perms=$(stat -f '%A' "$HOME")
if [[ "$_home_perms" != '700' ]]; then
  print -P "%F{yellow}Warning:%f ~ permissions are $_home_perms," \
    "expected 700. Fix: chmod 700 ~"
fi
unset _home_perms

# Redirect Playwright browser downloads to a shared path so all users can share
# one Chromium install instead of each user downloading their own copy.
export PLAYWRIGHT_BROWSERS_PATH=/Users/Shared/playwright

# Redirect model downloads to shared stores so all users share one set of
# weights: Ollama-managed GGUF models and the Hugging Face hub cache holding MLX
# checkpoints. HF_HUB_CACHE only, never HF_HOME (that would move auth tokens
# into the shared directory). See claude/docs/shared-storage.md.
export OLLAMA_MODELS=/Users/Shared/models/gguf
export HF_HUB_CACHE=/Users/Shared/models/mlx

# Ghostty sets TERM=xterm-ghostty but ships that terminfo entry only inside its
# app bundle, so a shell reached over ssh — claudify's included — cannot resolve
# it, and renders its prompt without color. Search the bundle directly;
# claude/docs/account-setup.md #terminfo covers the alternatives.
#
# `${TERMINFO_DIRS:-}` keeps any existing value. When there is none, the result
# begins with an empty entry, which stands for the system's own terminfo
# directories, so those are still searched first.
_ghostty_terminfo=/Applications/Ghostty.app/Contents/Resources/terminfo
export TERMINFO_DIRS="${TERMINFO_DIRS:-}:$_ghostty_terminfo"
unset _ghostty_terminfo

# Private environment variables (not tracked in the public repo).
#
# Status: deprecated; currently no private environment variables to import.
#[[ -f "$HOME/.zprofile_private" ]] && source "$HOME/.zprofile_private"
