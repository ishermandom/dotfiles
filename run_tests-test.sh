#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests what run_tests.sh runs when the Stop hook calls it, setting
# PYTEST_FROM_HOOK, against what it runs on any other call.
#
# Each case copies run_tests.sh into a scratch tree that holds one stand-in
# shell test, which records that it ran, and puts a stand-in `uv` first on PATH,
# which records the arguments pytest would have received. No real test runs, so
# the cases see only the script's choices.

script_dir=$(cd "$(dirname "$0")" && pwd)

. "$script_dir/claude/scripts/shell-test-framework.sh"

# --- helpers ----------------------------------------------------------------

# Builds the scratch tree under `$case_dir`: `repo/` holds run_tests.sh and a
# shell test that writes `$case_dir/shell-test-ran`, and `bin/` holds a `uv`
# that writes its arguments, one per line, to `$case_dir/uv-arguments`.
make_suite() {
  mkdir -p "$case_dir/repo/claude/hooks" "$case_dir/bin"
  cp "$script_dir/run_tests.sh" "$case_dir/repo/run_tests.sh"

  # The unquoted EOF expands `$case_dir` now, while the file is written; the
  # escaped `\$@` stays for the stand-in to expand when it runs.
  cat > "$case_dir/repo/claude/hooks/probe-test.sh" << EOF
#!/bin/sh
echo ran > "$case_dir/shell-test-ran"
EOF
  cat > "$case_dir/bin/uv" << EOF
#!/bin/sh
printf '%s\n' "\$@" > "$case_dir/uv-arguments"
EOF
  chmod +x "$case_dir/repo/claude/hooks/probe-test.sh" "$case_dir/bin/uv"
}

# --- cases ------------------------------------------------------------------

begin_case runs-everything-outside-the-hook
make_suite
(
  unset PYTEST_FROM_HOOK
  PATH="$case_dir/bin:$PATH" "$case_dir/repo/run_tests.sh" > /dev/null 2>&1
)
expect "runs the shell tests" [ -e "$case_dir/shell-test-ran" ]
expect "keeps the slow Python tests" \
  not_contains "$(cat "$case_dir/uv-arguments")" "not slow"

begin_case leaves-out-the-slow-tests-from-the-hook
make_suite
PYTEST_FROM_HOOK=1 PATH="$case_dir/bin:$PATH" \
  "$case_dir/repo/run_tests.sh" > /dev/null 2>&1
expect "skips the shell tests" [ ! -e "$case_dir/shell-test-ran" ]
# One argument per line, so the flag and its value sit on adjacent lines.
expect "deselects the tests marked slow" \
  contains "$(cat "$case_dir/uv-arguments")" $'-m\nnot slow'

# --- summary ----------------------------------------------------------------

exit_with_summary
