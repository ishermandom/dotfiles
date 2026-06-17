#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean test runner for intentional mid-turn checks: runs the project's
# ./run_tests.sh with short tracebacks, printing only the summary line on
# success and the full output on failure. The Stop hook remains the default
# way tests run; use this when a mid-turn check adds value.

if [ ! -x ./run_tests.sh ]; then
  echo "no executable ./run_tests.sh in $(pwd)" >&2
  exit 1
fi

output=$(PYTEST_ADDOPTS="--tb=short" ./run_tests.sh "$@" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "$output" | tail -1
else
  echo "$output"
fi
exit $status
