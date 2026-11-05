#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Lists the files under the current directory that git does not ignore.
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
