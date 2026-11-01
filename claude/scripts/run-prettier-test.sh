#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests which runtime run-prettier.sh starts prettier under, and that it hands
# prettier its arguments untouched.
#
# The launcher finds its tools on the caller's PATH, so each case gives it a
# PATH holding only stand-ins: a `prettier` and a `bun` that print their name
# and then each argument they received, one per line. No real prettier runs.

script_dir=$(cd "$(dirname "$0")" && pwd)
run_prettier="$script_dir/run-prettier.sh"

. "$script_dir/shell-test-framework.sh"

# --- stand-ins --------------------------------------------------------------

# Writes a stand-in that prints its own name, then each argument it was given.
# Each is written once, into the directories the cases put on PATH, since macOS
# scans every newly written executable the first time it runs.
write_stand_in() { # write_stand_in <directory> <name>
  mkdir -p "$1"
  printf '#!/bin/sh\necho %s\nprintf "%%s\\n" "$@"\n' "$2" > "$1/$2"
  chmod +x "$1/$2"
}

with_bun="$test_script_root/with-bun"
without_bun="$test_script_root/without-bun"
neither="$test_script_root/neither"
write_stand_in "$with_bun" prettier
write_stand_in "$with_bun" bun
write_stand_in "$without_bun" prettier
mkdir -p "$neither"

# Runs the launcher with only the given directory on PATH, capturing what it
# printed into `output` and its exit status into `exit_code`.
run_with_path() { # run_with_path <directory> <argument...>
  local directory="$1"
  shift
  output=$(PATH="$directory" "$run_prettier" "$@" 2>&1)
  exit_code=$?
}

# --- cases ------------------------------------------------------------------

# Bun runs prettier's own launcher file, which `command -v` resolves to a path.
begin_case runs-prettier-under-bun-when-both-are-installed
run_with_path "$with_bun" --write 'a b.md'
expect_equal "starts bun on prettier's path, passing the arguments whole" \
  "$output" "bun
$with_bun/prettier
--write
a b.md"

begin_case runs-plain-prettier-without-bun
run_with_path "$without_bun" --write 'a b.md'
expect_equal "starts prettier itself, passing the arguments whole" \
  "$output" "prettier
--write
a b.md"

# A missing prettier fails the way a missing command does, which is what the
# formatting step reads as a tool that could not run.
begin_case fails-with-127-without-prettier
run_with_path "$neither" --write 'a b.md'
expect "exits 127" [ "$exit_code" -eq 127 ]
expect "names prettier" contains "$output" "prettier"

# --- summary ----------------------------------------------------------------

exit_with_summary
