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

# -u turns an unset variable into an error; -e is deliberately absent, since it
# would abort mid-run without saying which package failed.
set -u

# $0 is this script's path; realpath resolves symlinks.
SCRIPT_PATH="$(realpath "$0")"
DOTFILES_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

# -n: no-op (simulate only); -v: verbose (print each link created/removed).
STOW_FLAGS=""
while getopts ":n" opt; do
  case "$opt" in
    n) STOW_FLAGS="-n -v" ;;
    *) echo "Usage: $SCRIPT_NAME [-n]" >&2; exit 1 ;;
  esac
done

# command -v reports whether a command exists without running it. Checking once
# up front keeps a missing stow from failing every package in turn.
if ! command -v stow > /dev/null; then
  echo "$SCRIPT_NAME: stow is not installed; try 'brew install stow'" >&2
  exit 1
fi

# Symlink a stow package into its target directory. Returns non-zero when
# linking fails; mkdir or stow has already reported the reason on stderr.
# Usage: stow_package <source_dir> <package> <target>
stow_package() {
  source_dir="$1"
  package="$2"
  target="$3"
  # Without a target directory stow has nothing to link into, so stop here
  # rather than compounding one failure with another.
  mkdir -p "$target" || return 1
  # --restow removes stale symlinks then recreates all links for this package,
  # which handles renames and deletions cleanly.
  # --no-folding keeps config dirs as real directories; most tools expect this.
  # Two packages want folding instead, for different reasons:
  #   claude — every subdirectory is hand-authored content (docs, skills,
  #     rules, …), so folding lets stow pick up new ones without curation.
  #   zed — Zed saves settings by writing a temp file and renaming it over the
  #     target, which replaces a per-file symlink with a plain file and quietly
  #     detaches the config from this repo. Folding links ~/.config/zed as a
  #     single directory symlink, so those renames land inside the repo.
  case "$package" in
    claude|zed) no_folding="" ;;
    *) no_folding="--no-folding" ;;
  esac
  # stow's exit status is the function's, so the caller sees linking failures.
  stow $STOW_FLAGS $no_folding --dir "$source_dir" --target "$target" \
    --restow "$package"
}

# Each package maps to the directory where its contents should appear. This
# pairing is the single source of truth, iterated for both the common packages
# and any per-account overlay. No package name or target contains a space, so a
# plain word-split loop is safe. To add a package, add a pair below.
#
# zed targets ~/.config rather than ~/.config/zed, and nests its own zed/
# directory inside the package, so that stow links that directory as a whole
# instead of linking its contents one file at a time — see the folding note
# above for why Zed needs it that way.
packages="
  claude:$HOME/.claude
  git:$HOME
  prettier:$HOME
  ruff:$HOME/.config/ruff
  zed:$HOME/.config
  zsh:$HOME
"

# Per-account overlays live under accounts/<account>/, mirroring the package
# layout, and override only the files that must differ per account (e.g. git's
# credential config, used for https token storage on the sandbox account
# alone). An account with no overlay directory just gets the common packages.
account_overlay="$DOTFILES_DIR/accounts/$(id -un)"  # id -un: current account

# Packages are independent, so one failure shouldn't hide the state of the
# rest: collect the names as they fail and report them together at the end.
failed_packages=""

for entry in $packages; do
  package="${entry%%:*}"  # text before the first colon
  target="${entry#*:}"    # text after the first colon
  stow_package "$DOTFILES_DIR" "$package" "$target" \
    || failed_packages="$failed_packages $package"
  # Layer this account's override for the package, when one exists.
  if [ -d "$account_overlay/$package" ]; then
    stow_package "$account_overlay" "$package" "$target" \
      || failed_packages="$failed_packages $package (account overlay)"
  fi
done

if [ -n "$failed_packages" ]; then
  echo "$SCRIPT_NAME: not linked (see errors above):$failed_packages" >&2
  exit 1
fi
