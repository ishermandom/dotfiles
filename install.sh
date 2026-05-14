#!/bin/sh
#
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# install.sh — symlinks dotfile packages into their target directories via stow.
#
# Each entry in PACKAGES maps a subdirectory of this repo (a "stow package")
# to the directory where its contents should appear as symlinks. For example,
# a package directory claude/ containing settings.json will produce a symlink
# at $HOME/.claude/settings.json pointing back into this repo.
#
# Usage: ./install.sh [-n]
#   -n  Dry run: print planned changes without modifying anything.

set -eu

# $0 is this script's path; realpath resolves symlinks.
SCRIPT_PATH="$(realpath "$0")"
DOTFILES_DIR="$(dirname "$SCRIPT_PATH")"

# -n: no-op (simulate only); -v: verbose (print each link created/removed).
STOW_FLAGS=""
while getopts ":n" opt; do
  case "$opt" in
    n) STOW_FLAGS="-n -v" ;;
    *) echo "Usage: $(basename "$0") [-n]" >&2; exit 1 ;;
  esac
done

# Symlink a stow package into its target directory.
# Usage: stow_package <package> <target>
stow_package() {
  package="$1"
  target="$2"
  mkdir -p "$target"
  # --restow removes stale symlinks then recreates all links for this package,
  # which handles renames and deletions cleanly.
  # --no-folding means that config dirs remain real directories rather than
  # symlinks, which can work better with some tools.
  stow $STOW_FLAGS --no-folding --dir "$DOTFILES_DIR" --target "$target" --restow "$package"
}

# To add a new package, uncomment or add a line below.
stow_package claude "$HOME/.claude"
stow_package git "$HOME"
stow_package ruff "$HOME/.config/ruff"
stow_package zsh "$HOME"
