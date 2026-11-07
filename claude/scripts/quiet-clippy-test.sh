#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests quiet-clippy.sh: the exit status and summary for a clean crate, a crate
# with a finding, and no crate at all, and that its color follows FORCE_COLOR,
# which cargo itself ignores. `file-listing-test.sh` covers which crates count,
# and `claude/hooks/clippy-lint-test.sh` the Stop step that drives the runner.
#
# The cases run the real `cargo clippy` over small crates in scratch repos.

script_dir=$(cd "$(dirname "$0")" && pwd)
quiet_clippy="$script_dir/quiet-clippy.sh"

source "$script_dir/shell-test-framework.sh"
source "$script_dir/homebrew-path.sh"

require_commands git cargo

# --- case helpers -----------------------------------------------------------

# Writes a crate at <directory> whose library is <source>.
make_crate() { # make_crate <directory> <source>
  mkdir -p "$1/src"
  printf '[package]\nname = "fixture"\nversion = "0.1.0"\nedition = "2024"\n' \
    > "$1/Cargo.toml"
  printf '%s\n' "$2" > "$1/src/lib.rs"
}

# Runs the runner from inside the case's repo with FORCE_COLOR set to <value>,
# leaving both streams in `$output` and the exit status in `$exit_code`.
run_runner() { # run_runner <FORCE_COLOR value>
  output=$(cd "$case_dir" && FORCE_COLOR=$1 "$quiet_clippy" 2>&1)
  exit_code=$?
}

clean='pub fn answer() -> u32 {
    42
}'
# Taking `&Vec` where a slice would do is one of clippy's default findings.
linted='pub fn total(values: &Vec<u32>) -> u32 {
    values.iter().sum()
}'
escape=$(printf '\033')

# --- cases ------------------------------------------------------------------

begin_case reports-no-crates
git -C "$case_dir" init --quiet
run_runner ""

expect "exits 0" test "$exit_code" -eq 0
expect "says there is nothing to lint" contains "$output" "no crates"

begin_case summarizes-a-clean-crate
git -C "$case_dir" init --quiet
make_crate "$case_dir" "$clean"
run_runner ""

expect "exits 0" test "$exit_code" -eq 0
expect "summarizes rather than listing crates" \
  contains "$output" "1 linted, clean"

# The second run replays the first's cached result, so the crate builds once.
begin_case colors-its-findings-only-under-force-color
git -C "$case_dir" init --quiet
make_crate "$case_dir" "$linted"
run_runner 3

expect "exits 1, the findings level" test "$exit_code" -eq 1
expect "passes on clippy's finding" contains "$output" "&Vec"
expect "in color, as the Stop hook's FORCE_COLOR asks" \
  contains "$output" "$escape"

run_runner ""
expect "and in plain text without FORCE_COLOR" not_contains "$output" "$escape"

# --- summary ----------------------------------------------------------------

exit_with_summary
