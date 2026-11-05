#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests run_tests.sh's choices: what it runs when the Stop hook calls it,
# setting PYTEST_FROM_HOOK, against what it runs on any other call, and how it
# runs the shell tests when it does.
#
# Each case copies run_tests.sh into a scratch tree that holds stand-in shell
# tests, and puts a stand-in `uv` first on PATH, which records the arguments
# pytest would have received. No real test runs, so the cases see only the
# script's choices.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/claude/scripts/shell-test-framework.sh"

# --- helpers ----------------------------------------------------------------

# Builds the scratch tree under `$case_dir`: `repo/` holds run_tests.sh, and
# `bin/` holds a `uv` that writes its arguments, one per line, to
# `$case_dir/uv-arguments`.
make_suite() {
  mkdir -p "$case_dir/repo/claude/hooks" "$case_dir/bin"
  cp "$script_dir/run_tests.sh" "$case_dir/repo/run_tests.sh"

  # The unquoted EOF expands `$case_dir` now, while the file is written; the
  # escaped `\$@` stays for the stand-in to expand when it runs.
  cat > "$case_dir/bin/uv" << EOF
#!/bin/sh
printf '%s\n' "\$@" > "$case_dir/uv-arguments"
EOF
  chmod +x "$case_dir/bin/uv"
}

# Adds a stand-in shell test named `<name>-test.sh` that runs the given
# commands.
add_shell_test() { # add_shell_test <name> <commands>
  printf '#!/bin/sh\n%s\n' "$2" > "$case_dir/repo/claude/hooks/$1-test.sh"
  chmod +x "$case_dir/repo/claude/hooks/$1-test.sh"
}

# Adds a stand-in shell test that marks itself started, then waits up to five
# seconds for the other named test to start, and says whether it did.
add_waiting_test() { # add_waiting_test <name> <other-name>
  add_shell_test "$1" "touch '$case_dir/$1-started'
waited=0
while [ ! -e '$case_dir/$2-started' ] && [ \$waited -lt 50 ]; do
  sleep 0.1
  waited=\$((waited + 1))
done
[ -e '$case_dir/$2-started' ] && echo '$1 saw $2 start'"
}

# Runs the scratch tree's run_tests.sh as any call but the Stop hook's would,
# printing what it printed.
run_suite() {
  # The parentheses scope the unset to this one run.
  (
    unset PYTEST_FROM_HOOK
    PATH="$case_dir/bin:$PATH" "$case_dir/repo/run_tests.sh" 2>&1
  )
}

# --- cases ------------------------------------------------------------------

begin_case runs-everything-outside-the-hook
make_suite
add_shell_test probe "echo ran > '$case_dir/shell-test-ran'"
run_suite > /dev/null
expect "runs the shell tests" [ -e "$case_dir/shell-test-ran" ]
expect "keeps the slow Python tests" \
  not_contains "$(cat "$case_dir/uv-arguments")" "not slow"

begin_case leaves-out-the-slow-tests-from-the-hook
make_suite
add_shell_test probe "echo ran > '$case_dir/shell-test-ran'"
PYTEST_FROM_HOOK=1 PATH="$case_dir/bin:$PATH" \
  "$case_dir/repo/run_tests.sh" > /dev/null 2>&1
expect "skips the shell tests" [ ! -e "$case_dir/shell-test-ran" ]
# One argument per line, so the flag and its value sit on adjacent lines.
expect "deselects the tests marked slow" \
  contains "$(cat "$case_dir/uv-arguments")" $'-m\nnot slow'

# Run one after another, the first test would give up waiting before the second
# ever started.
begin_case runs-the-shell-tests-in-parallel
make_suite
add_waiting_test first second
add_waiting_test second first
output=$(run_suite)
expect "starts the second test while the first still runs" \
  contains "$output" "first saw second start"

# The second test prints and fails while the first is between its two lines, so
# reports that streamed straight through would interleave.
begin_case prints-each-report-whole-and-in-order
make_suite
add_shell_test first "echo 'first report begins'
sleep 0.5
echo 'first report ends'"
add_shell_test second "sleep 0.2
echo 'second report'
exit 1"
output=$(run_suite)
exit_code=$?
expect "keeps each report whole, in the tests' order" contains "$output" \
  $'first report begins\nfirst report ends\nsecond report'
expect "fails the run when a test fails" [ "$exit_code" -ne 0 ]

# --- summary ----------------------------------------------------------------

exit_with_summary
