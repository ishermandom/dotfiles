#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Lists the files under the current directory that git does not ignore, and
# finds the Rust crates among them.
#
# Sourced rather than run, so listing the files starts no shell of its own. The
# shebang only names the dialect for shellcheck and editors, and the file is
# deliberately not executable.

# Prints the files under the current directory that match the given pathspecs,
# minus any git ignores, each ending in a NUL byte. Outside a repo, git fails
# without listing anything, so the caller can fall back on a listing of its own.
#
# - `--cached`: the tracked files; the index is what git calls its cache
# - `--others`: the untracked files too
# - `--exclude-standard`: minus any untracked file an ignore rule covers, such
#   as one in a build directory or in a worktree under `.claude/worktrees/`. Git
#   reads every ignore source — each folder's `.gitignore`, `.git/info/exclude`,
#   the global excludes file.
# - `-z`: each path ends in a NUL byte rather than a newline, and an unusual
#   name comes unquoted, so any name arrives whole
#
# git still lists a tracked file the working tree has deleted, so a caller
# checks that each listed file exists before handing it on.
list_unignored_files() { # list_unignored_files <pathspec>...
  git ls-files -z --cached --others --exclude-standard -- "$@" 2> /dev/null
}

# Sets the array `crate_manifests` to the Cargo.toml of every Rust crate under
# the current directory, each path relative to that directory. A crate's
# Cargo.toml is its manifest, which cargo takes through `--manifest-path`.
find_crate_manifests() {
  crate_manifests=()

  # `:(glob)` lets `**` match any number of directories, none included, so a
  # crate at the current directory counts too. Outside a repo, that crate is the
  # only candidate.
  #
  # `read -d ''` takes one NUL-ended path at a time, and `IFS=` and `-r` keep
  # its spaces and backslashes as they are. `< <(...)` feeds the loop the
  # listing while keeping the loop in this shell; piped into, the loop would run
  # in a subshell, and the array would come back empty.
  local manifest
  while IFS= read -r -d '' manifest; do
    # A deleted manifest is passed over, as is the candidate outside a repo when
    # the current directory holds no crate.
    if [ -f "$manifest" ]; then
      crate_manifests+=("$manifest")
    fi
  done < <(
    list_unignored_files ':(glob)**/Cargo.toml' || printf 'Cargo.toml\0'
  )
}
