#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for shellcheck-lint.sh: a finding halts the turn with shellcheck's own
# words, a clean repo passes silently, and a session below the repo root still
# lints the whole repo. `file-listing-test.sh` covers which files count as
# shell, and `quiet-shellcheck-test.sh` which of them are linted.
#
# The cases run the real shellcheck over small scratch repos.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/../scripts/shell-test-framework.sh"
source "$script_dir/../scripts/homebrew-path.sh"

require_commands git shellcheck shfmt

# --- case helpers -----------------------------------------------------------

# Runs the step from <directory>, leaving everything it printed in the case
# directory as `output`. Returns the step's exit status.
run_step() { # run_step <directory>
  (cd "$1" && "$script_dir/shellcheck-lint.sh") > "$case_dir/output" 2>&1
}

# --- cases ------------------------------------------------------------------

begin_case a-clean-repo-passes-silently
git -C "$case_dir" init --quiet
printf '#!/usr/bin/env bash\ncd /tmp || exit 1\n' > "$case_dir/guarded.sh"
run_step "$case_dir"
exit_code=$?

expect_equal "exits 0" "$exit_code" 0
expect_equal "prints nothing" "$(cat "$case_dir/output")" ""

begin_case a-finding-halts-the-turn
git -C "$case_dir" init --quiet
# An unguarded cd is SC2164, which shellcheck reports on any bash file.
printf '#!/usr/bin/env bash\ncd /tmp\n' > "$case_dir/unguarded.sh"
run_step "$case_dir"
exit_code=$?

expect "fails the step" test "$exit_code" -ne 0
expect "passes on shellcheck's finding" \
  contains "$(cat "$case_dir/output")" "SC2164"

begin_case a-session-below-the-root-lints-the-whole-repo
git -C "$case_dir" init --quiet
mkdir -p "$case_dir/tools" "$case_dir/docs"
printf '#!/usr/bin/env bash\ncd /tmp\n' > "$case_dir/tools/unguarded.sh"
run_step "$case_dir/docs"
exit_code=$?

expect "fails the step on the script elsewhere in the repo" \
  test "$exit_code" -ne 0

exit_with_summary
