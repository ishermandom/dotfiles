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
# Usage: stow_package <source_dir> <package> <target>
stow_package() {
  source_dir="$1"
  package="$2"
  target="$3"
  mkdir -p "$target"
  # --restow removes stale symlinks then recreates all links for this package,
  # which handles renames and deletions cleanly.
  # --no-folding keeps config dirs as real directories; most tools expect this.
  # claude omits it because all its subdirectories are hand-authored content
  # (docs, skills, rules, …), so directory folding lets stow automatically
  # pick up new ones without manual curation.
  no_folding="--no-folding"
  [ "$package" = "claude" ] && no_folding=""
  stow $STOW_FLAGS $no_folding --dir "$source_dir" --target "$target" --restow "$package"
}

# Each package maps to the directory where its contents should appear. This
# pairing is the single source of truth, iterated for both the common packages
# and any per-account overlay. No package name or target contains a space, so a
# plain word-split loop is safe. To add a package, add a pair below.
packages="
  claude:$HOME/.claude
  git:$HOME
  prettier:$HOME
  ruff:$HOME/.config/ruff
  zsh:$HOME
"

# Per-account overlays live under accounts/<account>/, mirroring the package
# layout, and override only the files that must differ per account (e.g. git's
# credential config, used for https token storage on the sandbox account
# alone). An account with no overlay directory just gets the common packages.
account_overlay="$DOTFILES_DIR/accounts/$(id -un)"  # id -un: current account

for entry in $packages; do
  package="${entry%%:*}"  # text before the first colon
  target="${entry#*:}"    # text after the first colon
  stow_package "$DOTFILES_DIR" "$package" "$target"
  # Layer this account's override for the package, when one exists.
  if [ -d "$account_overlay/$package" ]; then
    stow_package "$account_overlay" "$package" "$target"
  fi
done
