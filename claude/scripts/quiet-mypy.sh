#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean mypy runner for intentional mid-turn checks: prints only the
# success line when clean, full error output otherwise. Optional path arguments
# narrow the check (e.g. one file); the default is the current directory.
#
# Why cd to the repo root: with explicit_package_bases, mypy derives each file's
# fully-qualified module name from its path relative to the working directory,
# which it treats as a package base. Run from a subdirectory, a file's module
# name loses its package prefix (a nested module can look top-level), so its
# imports no longer match and mypy reports the package as untyped. mypy has no
# config switch to anchor the base independent of the working directory, so the
# standard practice — the same one pre-commit, tox, and CI follow — is to run
# mypy from the project root. We pass the original paths as targets, so the set
# of files checked is unchanged. Outside a git repo there's no root to anchor
# to, so run in place.

# Collect the paths to check into an array. "$#" and "$@" are the script's
# argument count and its arguments; with none, default to the current directory.
# Otherwise resolve each argument to an absolute path so it still points at the
# right file after the directory change below. (array+=(...) appends an element.)
targets=()
if [ $# -eq 0 ]; then
  targets=("$PWD")
else
  for path in "$@"; do
    targets+=("$(realpath "$path")")
  done
fi

# Anchor on the first target's repo root — the files' repo, which may differ
# from the current directory. git rev-parse must run from a directory, so step
# up when the target is a file. The ":-" fallback runs in place when the target
# is not in a git repo.
first_dir=${targets[0]}
[ -f "$first_dir" ] && first_dir=$(dirname "$first_dir")
repo_root=$(cd "$first_dir" && git rev-parse --show-toplevel 2>/dev/null)
run_dir="${repo_root:-$PWD}"

# Run mypy from run_dir. The cd is inside "$(...)", so it changes directory only
# for that subshell, not for this script. "${targets[@]}" expands the array to
# its elements.
output=$(cd "$run_dir" && mypy --strict "${targets[@]}" 2>&1)
status=$?

# Print only the summary line on success, the full output on failure.
if [ $status -eq 0 ]; then
  echo "$output" | tail -1
else
  echo "$output"
fi
exit $status
