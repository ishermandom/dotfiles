#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean mypy runner for intentional mid-turn checks: prints only the
# success line when clean, full error output otherwise. Optional path
# arguments narrow the check (e.g. one file); the default is the current
# directory, matching the Stop hook's check.

output=$(mypy --strict "${@:-.}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "$output" | tail -1
else
  echo "$output"
fi
exit $status
