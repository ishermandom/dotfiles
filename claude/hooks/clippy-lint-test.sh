#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for clippy-lint.sh: a finding halts the turn with clippy's own words, a
# clean crate or no crate passes silently, and a session below the repo root
# still checks the whole repo. `file-listing-test.sh` covers which crates count.
#
# The cases run the real `cargo clippy` over small crates in scratch repos.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/../scripts/shell-test-framework.sh"

# Homebrew's bin directory holds cargo, and is on PATH only when a login shell
# put it there.
export PATH="$PATH:/opt/homebrew/bin"
require_commands git cargo

# --- case helpers -----------------------------------------------------------

# Writes a crate at <directory> whose library is <source>.
make_crate() { # make_crate <directory> <source>
  mkdir -p "$1/src"
  printf '[package]\nname = "fixture"\nversion = "0.1.0"\nedition = "2024"\n' \
    > "$1/Cargo.toml"
  printf '%s\n' "$2" > "$1/src/lib.rs"
}

# Runs the step from <directory>, leaving everything it printed in the case
# directory as `output`. Returns the step's exit status.
run_step() { # run_step <directory>
  (cd "$1" && "$script_dir/clippy-lint.sh") > "$case_dir/output" 2>&1
}

clean='pub fn answer() -> u32 {
    42
}'
# Taking `&Vec` where a slice would do is one of clippy's default findings.
linted='pub fn total(values: &Vec<u32>) -> u32 {
    values.iter().sum()
}'

# --- cases ------------------------------------------------------------------

begin_case no-crate-passes-silently
git -C "$case_dir" init --quiet
run_step "$case_dir"
exit_code=$?

expect_equal "exits 0" "$exit_code" 0
expect_equal "prints nothing" "$(cat "$case_dir/output")" ""

begin_case a-clean-crate-passes-silently
git -C "$case_dir" init --quiet
make_crate "$case_dir" "$clean"
run_step "$case_dir"
exit_code=$?

expect_equal "exits 0" "$exit_code" 0
expect_equal "prints nothing" "$(cat "$case_dir/output")" ""

begin_case a-finding-halts-the-turn
git -C "$case_dir" init --quiet
make_crate "$case_dir" "$linted"
run_step "$case_dir"
exit_code=$?

expect "fails the step" test "$exit_code" -ne 0
expect "passes on clippy's finding" \
  contains "$(cat "$case_dir/output")" "&Vec"

begin_case a-session-below-the-root-checks-the-whole-repo
git -C "$case_dir" init --quiet
make_crate "$case_dir/tools" "$linted"
mkdir -p "$case_dir/docs"
run_step "$case_dir/docs"
exit_code=$?

expect "fails the step on the crate elsewhere in the repo" \
  test "$exit_code" -ne 0

exit_with_summary
