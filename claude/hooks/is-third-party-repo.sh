#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Decide whether a path sits in a checkout of someone else's project, so the
# formatting and checking hooks can leave that checkout to its own conventions.
# Exits 0 for a third-party checkout, 1 for the user's own, and 2 when called
# wrong — printing nothing on a verdict, so a hook can test it in an `if`.
#
# The signal is remote ownership: a repository is the user's own when every
# account its remotes name is one of the accounts below. That reading covers
# both shapes a third-party checkout takes — a plain clone, whose `origin`
# belongs to the project, and a fork, whose `origin` is the user's while an
# `upstream` remote still names the project it came from.
#
# Two defaults fall out of the same rule, and both are deliberate:
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
