#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Decide whether a path sits in a checkout of someone else's project, so the
# formatting and checking hooks can leave that checkout to its own conventions.
# Exits 0 for a third-party checkout, 1 for the user's own, and 2 when called
# wrong — printing nothing on a verdict, so a hook can test it in an `if`.
#
# The main signal is remote ownership: a repository is the user's own when every
# account its remotes name is one of the accounts below. That reading covers
# both shapes a third-party git checkout takes — a plain clone, whose `origin`
# belongs to the project, and a fork, whose `origin` is the user's while an
# `upstream` remote still names the project it came from.
#
# A gclient checkout — the tree of git repos that depot_tools assembles for
# Chromium and related projects — needs a signal of its own. Its root is a plain
# directory holding a `.gclient` file rather than a repo, so a session started
# there has no remotes to read. Instead, anything at or below a `.gclient` file
# counts as someone else's, found by the same walk up the tree that gclient
# itself uses to locate its root.
#
# Two defaults fall out of remote ownership, and both are deliberate:
#
# - a repository with no remotes at all is the user's own, so a project not yet
#   pushed anywhere keeps its checks
# - a remote URL in a shape carrying no recognizable account — a bare local
#   path, say — reads as someone else's, because the hooks this guards rewrite
#   files, and rewriting a stranger's repository is the costlier mistake
#
# The verdict is deliberately not overridable for now, as there is no concrete
# use case: tasks.md #third-party-override.

# The accounts whose repositories count as the user's own.
owned_account_names=(ishermandom)

if [ $# -ne 1 ]; then
  echo "usage: $(basename "$0") <path>" >&2
  exit 2
fi

# git takes a directory, so a file argument stands for the directory holding it
# — which lets a caller pass an edited file's path straight through.
target=$1
[ -d "$target" ] || target=$(dirname "$target")

# The account a URL names, or empty for a shape that names none.
#
# `git@github.com:owner/repo.git` and `https://github.com/owner/repo` both put
# the account in the segment before the repository name, so rewriting the SSH
# form's `:` as a `/` leaves a single shape to read. The same rewrite mangles a
# scheme's `//` into `///`, harmlessly: only the last two segments are read.
remote_account_name() { # remote_account_name <remote url>
  local path=${1%.git}
  path=${path%/}
  # `${path//:/\/}` replaces every `:` in the URL with a `/`.
  path=${path//:/\/}

  # Drop the repository name, then keep the last segment of what is left.
  local without_repository=${path%/*}
  printf '%s' "${without_repository##*/}"
}

is_owned_account() { # is_owned_account <account name>
  local owned_account_name
  for owned_account_name in "${owned_account_names[@]}"; do
    [ "$1" = "$owned_account_name" ] && return 0
  done
  return 1
}

# Whether a directory sits at or below the root of a gclient checkout, which
# gclient marks with a `.gclient` file.
is_inside_gclient_checkout() { # is_inside_gclient_checkout <directory>
  # The walk up needs an absolute path to end at `/`. A directory that does not
  # exist resolves to nothing, and lies in no checkout. `local` takes a line of
  # its own so that `||` sees realpath's exit status rather than local's.
  local directory
  directory=$(realpath "$1" 2> /dev/null) || return 1

  while [ "$directory" != / ]; do
    [ -f "$directory/.gclient" ] && return 0
    directory=$(dirname "$directory")
  done
  return 1
}

# The gclient marker is read ahead of the remotes, so a repo inside such a tree
# stays someone else's even when its remote was repointed at the user's fork.
is_inside_gclient_checkout "$target" && exit 0

repository_root=$(git -C "$target" rev-parse --show-toplevel 2> /dev/null)

# Outside a checkout there is no ownership question to answer.
[ -n "$repository_root" ] || exit 1

# `mapfile -t` reads the lines into an array without their trailing newlines.
mapfile -t remote_names < <(git -C "$repository_root" remote)

for remote_name in "${remote_names[@]}"; do
  # `get-url --all` prints every URL one remote carries — a fork can track
  # several upstreams under a single remote.
  mapfile -t remote_urls < <(
    git -C "$repository_root" remote get-url --all "$remote_name"
  )

  for remote_url in "${remote_urls[@]}"; do
    account_name=$(remote_account_name "$remote_url")
    is_owned_account "$account_name" || exit 0
  done
done

exit 1
