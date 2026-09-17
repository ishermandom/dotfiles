# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# `wt <worktree>` opens a git worktree in Zed, wherever that worktree lives.
# Every project under the code root (`WORKTREE_CODE_ROOT` below) keeps its
# worktrees in the same place, `.claude/worktrees/`, so a name alone is enough
# to find the directory. Tab completion lists the names.
#
# Two projects can each hold a worktree of the same name. A bare name that
# matches both is refused rather than guessed at; writing `<project>/<name>`
# picks out a single worktree, and completion offers that qualified form
# wherever two projects share a name.
#
# NB: The `compdef` at the foot of this file requires `compinit` to have run
# already. `.zshrc` sources this file after its `compinit` call.

# The tree holding every project. `:-` keeps whatever the environment already
# set, allowing tests to point the command at a scratch tree.
WORKTREE_CODE_ROOT=${WORKTREE_CODE_ROOT:-/Users/Shared/code}

# Where each project keeps its worktrees, relative to the project root.
_worktree_subdirectory=".claude/worktrees"

# Opens a worktree in Zed. Tab completion after `wt ` lists every worktree
# available.
wt() { # wt <worktree>
  # `$#` is the argument count.
  if (($# != 1)); then
    print -ru2 -- "usage: wt <worktree> — press Tab to list the worktrees"
    return 2
  fi

  local directory
  directory=$(_worktree_resolve "$1") || return 1
  zed "$directory"
}

# Prints the directory of the worktree a query names. When no single worktree
# matches, prints the reason to stderr and returns non-zero. A query is a bare
# worktree name, or the qualified `<project>/<name>` form — the latter is the
# only way to uniquely identify a worktree whose name is duplicated across two
# or more projects.
_worktree_resolve() { # _worktree_resolve <query>
  local query=$1

  # Quoting the command substitution lets `f` split on newlines. Unquoted, the
  # newlines collapse to spaces first, leaving `f` a single line to split.
  local -a names=(${(f)"$(_worktree_names)"})

  local -a matches=()
  local name
  for name in $names; do
    # Inside `[[ ]]`, the right side of `==` is a glob pattern. Quoting
    # `$query` makes it literal, so a query holding `*` or `?` matches a name
    # spelled that way rather than every name it could glob.
    [[ $name == "$query" || ${name:t} == "$query" ]] && matches+=($name)
  done

  if ((${#matches} == 0)); then
    print -ru2 -- "wt: no worktree named '$query' under $WORKTREE_CODE_ROOT"
    return 1
  fi

  if ((${#matches} > 1)); then
    print -ru2 -- "wt: '$query' matches ${#matches} worktrees:"
    for name in $matches; do
      print -ru2 -- "  $name"
    done
    return 1
  fi

  # `%/*` keeps the project, and `#*/` keeps the worktree's own name.
  local project_directory="$WORKTREE_CODE_ROOT/${matches[1]%/*}"
  print -r -- "$project_directory/$_worktree_subdirectory/${matches[1]#*/}"
}

# Prints every worktree as `<project>/<name>`, one per line. Resolution and
# completion both work from this listing.
_worktree_names() {
  # Glob qualifiers: `/` keeps directories only, and `N` yields nothing rather
  # than an error when no project holds a worktree.
  local -a directories=($WORKTREE_CODE_ROOT/*/$_worktree_subdirectory/*(N/))

  local directory project
  for directory in $directories; do
    # A checkout carries a `.git` file pointing at the repository. A directory
    # here without that file is not a worktree: naming a worktree
    # `feature/parser` makes `feature` a plain parent directory, and anything
    # else that wandered in is no worktree either.
    #
    # TODO: reach a worktree whose name holds a slash. Finding one means
    # recursing through a checkout's whole contents, which costs more than the
    # case is worth while no such worktree exists.
    [[ -e $directory/.git ]] || continue

    # Drop the code root, then keep the leading segment — the project's name.
    project=${directory#"$WORKTREE_CODE_ROOT"/}
    project=${project%%/*}
    # `:t` is a path's tail: here, the worktree's own directory name.
    print -r -- "$project/${directory:t}"
  done
}

# Prints what Tab completion offers: a bare name where that name is unique, and
# the qualified `<project>/<name>` forms where two projects share a name, since
# `wt` would refuse the bare name.
_worktree_candidates() {
  local -a names=(${(f)"$(_worktree_names)"})

  # How many projects hold each bare name. Arithmetic reads an unset element as
  # zero, so the increment needs no initialization.
  local -A project_count=()
  local name
  for name in $names; do
    ((project_count[${name:t}]++))
  done

  for name in $names; do
    if ((project_count[${name:t}] > 1)); then
      print -r -- "$name"
    else
      print -r -- "${name:t}"
    fi
  done
}

# `_<command>` is the zsh convention for naming a completion function, and the
# `compdef` below binds `_wt` to `wt`. Everything `_wt` offers comes from
# `_worktree_candidates`, which holds the bare-or-qualified policy.
_wt() {
  local -a candidates=(${(f)"$(_worktree_candidates)"})
  compadd -- $candidates
}

compdef _wt wt
