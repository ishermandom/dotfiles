#!/bin/sh
#
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# configure-account-remotes.sh — point every shared repo at the Git remote the
# running account can actually reach.
#
# Both accounts on this machine share the working copies under
# /Users/Shared/code, but reach GitHub over different transports: one over ssh
# (`origin`), the other over https (`origin-https`). The choice cannot live in
# a per-account global file, because a repo's own config outranks global config
# and `git clone` writes branch.main.remote into it. So each shared repo's
# config includes ~/.config/git/account-remote instead, whose ~/-relative path
# resolves to the running account's own stowed copy.
#
# Only repos carrying both remotes are wired. With a single transport there is
# nothing to choose between, and naming a remote the repo lacks would break its
# fetches.
#
# Run once per account, and again after cloning a repo that has both remotes.
# Re-running is harmless.
#
# Usage: ./configure-account-remotes.sh [-n]
#   -n  Dry run: report what would change without modifying anything.

# -u turns an unset variable into an error; -e is deliberately absent, since it
# would abort mid-run without saying which repo failed.
set -u

SCRIPT_NAME="$(basename "$0")"

SHARED_CODE_DIR="/Users/Shared/code"

# The tilde stays literal in the config file: Git expands it per account when
# it reads the include, which is what lets one line serve both accounts.
ACCOUNT_REMOTE_INCLUDE="~/.config/git/account-remote"

is_dry_run=""
while getopts ":n" opt; do
  case "$opt" in
    n) is_dry_run="yes" ;;
    *) echo "Usage: $SCRIPT_NAME [-n]" >&2; exit 1 ;;
  esac
done

# The include stays inert until this account's own copy of the file exists, so
# a missing one means the stow packages haven't been installed here yet.
account_remote_file="$HOME/.config/git/account-remote"
if [ ! -e "$account_remote_file" ]; then
  echo "$SCRIPT_NAME: $account_remote_file is missing — run ./install.sh" >&2
  exit 1
fi

# A repo has a transport to choose only when it carries both remotes. Compare
# whole names: `origin-https` contains `origin` as a substring.
has_both_transports() {
  has_ssh_remote=""
  has_https_remote=""
  # Remote names cannot contain spaces, so a plain word-split loop is safe.
  for remote in $(git -C "$1" remote); do
    [ "$remote" = "origin" ] && has_ssh_remote="yes"
    [ "$remote" = "origin-https" ] && has_https_remote="yes"
  done
  [ -n "$has_ssh_remote" ] && [ -n "$has_https_remote" ]
}

# include.path may hold several entries, so check every one for ours.
is_already_wired() {
  for existing in $(git -C "$1" config --local --get-all include.path); do
    [ "$existing" = "$ACCOUNT_REMOTE_INCLUDE" ] && return 0
  done
  return 1
}

action_verb="wired"
[ -n "$is_dry_run" ] && action_verb="would wire"

changed_repos=""
failed_repos=""
needs_fetch_repos=""

for repo in "$SHARED_CODE_DIR"/*/; do
  repo_name="$(basename "$repo")"
  # A worktree carries a .git file where a main checkout has a directory. Both
  # resolve to one config, so whichever is reached first covers the repo.
  [ -e "$repo/.git" ] || continue
  has_both_transports "$repo" || continue

  # A dry run reports intent only, so it stops before inspecting repo state.
  if [ -n "$is_dry_run" ]; then
    is_already_wired "$repo" || changed_repos="$changed_repos $repo_name"
    continue
  fi

  if ! is_already_wired "$repo"; then
    if git -C "$repo" config --local --add \
        include.path "$ACCOUNT_REMOTE_INCLUDE"; then
      changed_repos="$changed_repos $repo_name"
    else
      failed_repos="$failed_repos $repo_name"
      continue
    fi
  fi

  # Selecting a remote does not create its tracking refs — those arrive on the
  # first fetch, and until then `git status` cannot resolve the upstream.
  selected_remote="$(git -C "$repo" config --get branch.main.remote)"
  if ! git -C "$repo" rev-parse --verify --quiet \
      "refs/remotes/$selected_remote/main" > /dev/null; then
    needs_fetch_repos="$needs_fetch_repos $repo_name"
  fi
done

if [ -n "$changed_repos" ]; then
  echo "$SCRIPT_NAME: $action_verb:$changed_repos"
else
  echo "$SCRIPT_NAME: every dual-transport repo is already wired"
fi

if [ -n "$needs_fetch_repos" ]; then
  echo "$SCRIPT_NAME: run 'git fetch' once in:$needs_fetch_repos"
fi

if [ -n "$failed_repos" ]; then
  echo "$SCRIPT_NAME: could not wire (see errors above):$failed_repos" >&2
  exit 1
fi
