#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean test runner for intentional mid-turn checks: runs the project's
# ./run_tests.sh with short tracebacks, printing only the summary line on
# success and the full output on failure. The Stop hook remains the default
# way tests run; use this when a mid-turn check adds value.
#
# Why cd to the repo root: run_tests.sh lives at the repo root and is invoked
# as ./run_tests.sh, so a caller in a subdirectory would miss it even though
# the repo is unambiguous. Anchor on the repo root the same way
# quiet-mypy.sh and quiet-ruff.sh do, rather than requiring the caller to
# already be there. Outside a git repo there's no root to anchor to, so run
# in place.

repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
run_dir="${repo_root:-$PWD}"

if [ ! -x "$run_dir/run_tests.sh" ]; then
  echo "no executable run_tests.sh in $run_dir" >&2
  exit 1
fi

output=$(cd "$run_dir" && PYTEST_ADDOPTS="--tb=short" ./run_tests.sh "$@" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "$output" | tail -1
else
  echo "$output"
fi
exit $status
