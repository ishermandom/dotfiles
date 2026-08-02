#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests the order stop_checks.sh runs its steps in, and what reaches the user
# when one of them fails.
#
# Each behavior here regresses silently: a step running out of order, or
# formatter chatter garbling the verdict, leaves a turn that ends clean while
# something is broken. That is why the assertions parse the verdict as JSON,
# the way Claude Code does, rather than matching loose text.
#
# The fixtures replace the real steps with fakes. stop_checks.sh resolves its
# steps from its own directory, so a copy of it beside four fake steps runs
# them — no test-only seam in the script, and no risk of the real steps
# re-entering this suite through pytest.

script_dir=$(cd "$(dirname "$0")" && pwd)
stop_checks="$script_dir/stop_checks.sh"

if ! command -v jq > /dev/null; then
  echo "stop_checks-test: jq is missing; try 'brew install jq'" >&2
  exit 1
fi

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

failure_count=0

# --- helpers ----------------------------------------------------------------

# Runs the given command as an assertion: prints one result line, and on
# failure bumps failure_count so the script exits non-zero at the end.
expect() { # expect <description> <command...>
  local description="$1"
  shift
  if "$@"; then
    echo "  ok: $description"
  else
    echo "  FAIL: $description" >&2
    failure_count=$((failure_count + 1))
  fi
}

contains() { # contains <haystack> <needle>
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

write_step() { # write_step <steps dir> <step name> <body>
  printf '#!/usr/bin/env bash\n%s\n' "$3" > "$1/$2"
  chmod +x "$1/$2"
}

# Builds a fixture directory: a copy of stop_checks.sh plus a do-nothing fake
# for each of its four steps. A case overrides only the steps it is about.
make_steps_dir() { # make_steps_dir  -> prints the directory
  local steps_dir
  steps_dir=$(mktemp -d "$test_root/steps.XXXXXX")
  cp "$stop_checks" "$steps_dir/"
  local step
  for step in prettier-format.sh ruff-format.sh mypy-check.sh run_tests.sh; do
    write_step "$steps_dir" "$step" "exit 0"
  done
  echo "$steps_dir"
}

# --- the steps run in a fixed order -----------------------------------------

steps=$(make_steps_dir)
for step in prettier-format.sh ruff-format.sh mypy-check.sh run_tests.sh; do
  write_step "$steps" "$step" "echo $step >> $steps/order.log"
done
"$steps/stop_checks.sh" > /dev/null

expect "formatters run before checks, each pair in order" \
  test "$(cat "$steps/order.log")" = "prettier-format.sh
ruff-format.sh
mypy-check.sh
run_tests.sh"

# --- a clean run says nothing -----------------------------------------------

steps=$(make_steps_dir)
write_step "$steps" "mypy-check.sh" "exit 0"
write_step "$steps" "run_tests.sh" "exit 0"
clean_output=$("$steps/stop_checks.sh")
clean_status=$?

expect "a clean run prints no verdict" test -z "$clean_output"
expect "a clean run exits 0" test "$clean_status" -eq 0

# --- a failing check halts the turn -----------------------------------------

steps=$(make_steps_dir)
write_step "$steps" "mypy-check.sh" 'echo "error: Missing return statement"
exit 1'
verdict=$("$steps/stop_checks.sh")
reason=$(jq -r '.stopReason' <<< "$verdict")

expect "a failing check halts the stop" \
  test "$(jq -r '.continue' <<< "$verdict")" = "false"
expect "the check's own output becomes the reason" \
  test "$reason" = "error: Missing return statement"

# --- a check may report on either stream ------------------------------------

steps=$(make_steps_dir)
write_step "$steps" "mypy-check.sh" 'echo "error: Need type annotation" >&2
exit 1'
reason=$(jq -r '.stopReason' <<< "$("$steps/stop_checks.sh")")

expect "a check that reports on stderr still reaches the user" \
  test "$reason" = "error: Need type annotation"

# --- a failing check skips the checks after it ------------------------------

steps=$(make_steps_dir)
write_step "$steps" "mypy-check.sh" "exit 1"
write_step "$steps" "run_tests.sh" "echo ran >> $steps/tests.log"
"$steps/stop_checks.sh" > /dev/null

expect "the tests are skipped once mypy has failed" \
  test ! -e "$steps/tests.log"

# --- formatter chatter stays out of the verdict -----------------------------

steps=$(make_steps_dir)
write_step "$steps" "ruff-format.sh" \
  "echo 'B905 zip() without an explicit \"strict=\" parameter'"
write_step "$steps" "mypy-check.sh" 'echo "error: Incompatible types"
exit 1'
verdict=$("$steps/stop_checks.sh")

expect "a formatter's output does not garble the verdict" \
  test "$(jq -r '.stopReason' <<< "$verdict")" = "error: Incompatible types"

# --- a broken formatter halts rather than going unnoticed -------------------

# The fake writes to both streams: asserting the reason is the stderr line
# proves stdout was dropped and stderr kept, not the reverse.
steps=$(make_steps_dir)
write_step "$steps" "prettier-format.sh" 'echo "reformatted 12 files"
echo "prettier: command not found" >&2
exit 127'
write_step "$steps" "mypy-check.sh" "echo ran >> $steps/mypy.log"
verdict=$("$steps/stop_checks.sh")
reason=$(jq -r '.stopReason' <<< "$verdict")

expect "a broken formatter halts the stop" \
  test "$(jq -r '.continue' <<< "$verdict")" = "false"
expect "the formatter's stderr becomes the reason" \
  test "$reason" = "prettier: command not found"
expect "the checks are skipped once a formatter has broken" \
  test ! -e "$steps/mypy.log"

# --- a check that fails silently is still named -----------------------------

steps=$(make_steps_dir)
write_step "$steps" "run_tests.sh" "exit 3"
verdict=$("$steps/stop_checks.sh")
reason=$(jq -r '.stopReason' <<< "$verdict")

expect "a silent failure names the step" contains "$reason" "run_tests.sh"
expect "a silent failure reports the exit status" contains "$reason" "3"

# --- summary ----------------------------------------------------------------

if [ "$failure_count" -ne 0 ]; then
  echo "stop_checks-test: $failure_count assertion(s) failed" >&2
  exit 1
fi
echo "stop_checks-test: all assertions passed"
