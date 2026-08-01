#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Test suite for the dotfiles repo — the unit tests under claude/hooks and
# claude/scripts.
# Run directly, or via ~/.claude/scripts/quiet-tests.sh (which the Stop test
# hook invokes). Honors PYTEST_ADDOPTS, which the quiet wrapper sets to
# --tb=short. The import paths the test modules need live in the root
# pyproject.toml. Arguments are forwarded to pytest; naming a path narrows the
# run to that path.

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

if [ "$names_test_path" = false ]; then
  # `set --` puts the suite's directories ahead of the caller's options.
  set -- "$root/claude/hooks" "$root/claude/scripts" "$@"
fi

exec python3 -m pytest "$@"
