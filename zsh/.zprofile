# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

# Homebrew — sets PATH, MANPATH, INFOPATH. Works for both Intel and Apple
# Silicon by resolving the prefix at login time.
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

export EDITOR="emacs -nw"
