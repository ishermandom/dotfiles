#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean ruff runner: lint-fix and format the given paths (default: the
# current directory), printing one summary line when clean and the remaining
# issues otherwise. Canonical ruff invocation — the Stop hook delegates here.

paths=("$@")
[ ${#paths[@]} -eq 0 ] && paths=(.)

check_output=$(ruff check --fix "${paths[@]}" 2>&1)
check_status=$?
format_output=$(ruff format "${paths[@]}" 2>&1)
format_status=$?

if [ $check_status -eq 0 ] && [ $format_status -eq 0 ]; then
  echo "$format_output" | tail -1
else
  printf '%s\n%s\n' "$check_output" "$format_output"
fi

status=$check_status
[ $format_status -ne 0 ] && status=$format_status
exit $status
