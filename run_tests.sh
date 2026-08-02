#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Test suite for the dotfiles repo — the Python unit tests under claude/hooks
# and claude/scripts, plus the standalone shell tests sitting beside them.
# Run directly, or via ~/.claude/scripts/quiet-tests.sh (which the Stop test
# hook invokes). Honors PYTEST_ADDOPTS, which the quiet wrapper sets to
# --tb=short. The import paths the test modules need live in the root
# pyproject.toml. Arguments are forwarded to pytest; naming a path narrows the
# run to that path, and to pytest alone — the shell tests take no arguments.

# Resolve the test directories against the script's own location so the suite
# runs identically regardless of the caller's working directory; per the
# testing convention we never cd. pyproject.toml's testpaths would be the
# tidier home for the list, but pytest honors testpaths only when invoked from
# the rootdir.
root="$(dirname "$0")"

# The suite's directories are a default, not a floor: a path the caller names
# stands on its own, so a path forwarded from ~/.claude/scripts/quiet-tests.sh
# narrows the run rather than adding to everything. Options carry no such
# meaning, so `-k expression` still runs against the whole suite.
#
# Recognize a path by whether it exists rather than by a leading dash — an
# option's value is a bare word too, and mistaking `expression` for a path
# would silently leave pytest collecting from the caller's directory.
names_test_path=false
for argument in "$@"; do
  # `${argument%%::*}` drops the selector from a node id, leaving the file.
  if [ -e "${argument%%::*}" ]; then
    names_test_path=true
    break
  fi
done

shell_test_status=0
if [ "$names_test_path" = false ]; then
  # The shell tests are standalone executables, which pytest cannot collect,
  # so the suite runs them itself. They go first so a passing run still ends
  # on pytest's summary — the one line quiet-tests.sh keeps on success.
  shell_tests=("$root"/claude/hooks/*-test.sh "$root"/claude/scripts/*-test.sh)
  for shell_test in "${shell_tests[@]}"; do
    # An unmatched glob stays literal in bash, so -e skips the pattern itself.
    [ -e "$shell_test" ] || continue
    "$shell_test" || shell_test_status=1
  done

  # `set --` puts the suite's directories ahead of the caller's options.
  set -- "$root/claude/hooks" "$root/claude/scripts" "$@"
fi

python3 -m pytest "$@"
pytest_status=$?

# Either half failing fails the run.
[ $shell_test_status -ne 0 ] && exit 1
exit $pytest_status
