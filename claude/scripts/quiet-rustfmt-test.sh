#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for quiet-rustfmt.sh: a crate comes out formatted, and a file rustfmt
# cannot parse reads as breakage rather than as a clean run.
# `file-listing-test.sh` covers which crates count.
#
# The cases run the real `cargo fmt` over small crates in scratch directories.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/shell-test-framework.sh"

# Homebrew's bin directory holds cargo, and is on PATH only when a login shell
# put it there.
export PATH="$PATH:/opt/homebrew/bin"
require_commands git cargo

# --- case helpers -----------------------------------------------------------

# Writes a crate at <directory> whose library is <source>, on the 2024 edition
# the repo's own crate uses.
make_crate() { # make_crate <directory> <source>
  mkdir -p "$1/src"
  printf '[package]\nname = "fixture"\nversion = "0.1.0"\nedition = "2024"\n' \
    > "$1/Cargo.toml"
  printf '%s\n' "$2" > "$1/src/lib.rs"
}

# Runs the runner from <directory>, leaving everything it printed in the case
# directory as `output`. Returns the runner's exit status.
run_runner() { # run_runner <directory> [argument...]
  local directory=$1
  shift
  (cd "$directory" && "$script_dir/quiet-rustfmt.sh" "$@") \
    > "$case_dir/output" 2>&1
}

unformatted='pub fn answer()->u32{42}'
formatted='pub fn answer() -> u32 {
    42
}'

# --- cases ------------------------------------------------------------------

begin_case no-crate-passes-silently
git -C "$case_dir" init --quiet
run_runner "$case_dir"
exit_code=$?

expect_equal "exits 0" "$exit_code" 0
expect_equal "prints nothing" "$(cat "$case_dir/output")" ""

begin_case a-crate-below-the-root-is-formatted
git -C "$case_dir" init --quiet
make_crate "$case_dir/tools" "$unformatted"
run_runner "$case_dir"
exit_code=$?

expect_equal "exits 0" "$exit_code" 0
expect_equal "the crate comes out formatted" \
  "$(cat "$case_dir/tools/src/lib.rs")" "$formatted"

begin_case an-unparseable-file-is-breakage
git -C "$case_dir" init --quiet
make_crate "$case_dir" 'pub fn answer( -> u32 {'
run_runner "$case_dir"
exit_code=$?

expect_equal "exits 2, the level format.sh reads as breakage" "$exit_code" 2
expect "passes on what rustfmt said" \
  contains "$(cat "$case_dir/output")" "error"

begin_case an-argument-is-a-usage-error
run_runner "$case_dir" src
exit_code=$?

expect_equal "exits 2" "$exit_code" 2
expect "prints the usage line" \
  contains "$(cat "$case_dir/output")" "usage: quiet-rustfmt.sh"

exit_with_summary
