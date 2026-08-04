#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# The test framework for the repo's shell test scripts, sourced rather than run.
# The shebang above tells shellcheck and editors which dialect to read this in;
# the file is deliberately left non-executable, since sourcing is the only way
# to use it.
#
# pytest gives the Python tests their scratch space, their assertions and their
# reporting. Shell has no runner, so this file plays that part. A test script
# sources it as its first act and gets:
#
# - `$test_script_root`, an empty directory that disappears on exit
# - `require_commands`, to stop with a clear message when a tool is missing
# - `begin_case`, which announces a test case and hands it `$case_dir`
# - `expect`, plus the `contains` and `not_contains` predicates
# - `report_summary`, the last line of every test script
#
# Two edges to know about before writing a test script against this:
#
# - Cleanup rides on an EXIT trap installed here. A test script that installs an
#   EXIT trap of its own silently replaces this one, and its scratch tree then
#   outlives the run. Such a script has to remove `$test_script_root` itself.
# - `report_summary` belongs on the last line, and its return value has to reach
#   the shell — see its own comment for why it returns rather than exiting, and
#   what breaks when something swallows that value.
#
# The file name deliberately avoids ending in `-test.sh`, the glob run_tests.sh
# collects test scripts with — a name inside that glob would have the suite try
# to run this file as one.

# --- the test script's identity and scratch space ---------------------------

# Importing this file via sourcing leaves $0 alone, so it still names the test
# script being run. Every message below carries that name, which saves each
# script from spelling it out in the lines it prints.
test_script_name=$(basename "$0" .sh)

# Somewhere to build fixtures. The trap covers every way the run can end, a
# `require_commands` bail-out included — subject to the EXIT trap caveat in the
# header.
test_script_root=$(mktemp -d)
trap 'rm -rf "$test_script_root"' EXIT

# --- preflight --------------------------------------------------------------

# Ends the run when a command the test script depends on is absent, naming every
# one that is missing so a single run tells the whole story. Without the check,
# a missing tool surfaces later as a failure in whichever case first reaches for
# it, where it reads as a bug in the script under test.
require_commands() { # require_commands <command>...
  local missing=()
  local command_name
  for command_name in "$@"; do
    command -v "$command_name" > /dev/null || missing+=("$command_name")
  done

  if [ ${#missing[@]} -gt 0 ]; then
    # `${missing[*]}` joins the names with a space, which serves as both a
    # readable list and a brew command that installs all of them at once.
    echo "$test_script_name: missing ${missing[*]};" \
      "try 'brew install ${missing[*]}'" >&2
    exit 1
  fi
}

# --- test cases -------------------------------------------------------------

# Announces a test case and gives it an empty directory of its own, `$case_dir`,
# so no case can see what another one left behind.
begin_case() { # begin_case <name>
  echo "case: $1"
  case_dir="$test_script_root/$1"
  mkdir -p "$case_dir"
}

# --- assertions -------------------------------------------------------------

# Assertions that have failed so far — `expect` bumps it and `report_summary`
# reports it, so a sourcing test script never touches it.
failure_count=0

# Runs the given command as an assertion: prints one result line, and on failure
# bumps failure_count so the run ends non-zero.
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

not_contains() { # not_contains <haystack> <needle>
  ! contains "$1" "$2"
}

# --- the verdict ------------------------------------------------------------

# Prints the run's verdict and returns 0 when every assertion passed, 1
# otherwise. Call it on the test script's last line: a script that runs off its
# end exits with the status of its last command, so this return value becomes
# the exit status that run_tests.sh reads.
#
# Returning rather than calling `exit` is what keeps the test scripts free of
# lint suppressions, by way of three facts:
#
# - A function that is never invoked draws SC2329. A predicate handed to
#   `expect` is only ever invoked through `expect`'s own `"$@"`, so no call to
#   it appears anywhere for shellcheck to find.
# - That report is held back while the file could be a library some other file
#   sources, since the calls could just as well live in that file.
# - A definite top-level `exit` settles the question, because only a standalone
#   program ends that way. Any of them does it — a bare `exit 0`, or an
#   `exit $?` wrapped around this function's result.
#
# Ending on a return leaves the question open, so the report never fires.
report_summary() {
  echo
  if [ "$failure_count" -eq 0 ]; then
    echo "$test_script_name: all passed"
    return 0
  fi
  echo "$test_script_name: $failure_count assertion(s) failed" >&2
  return 1
}
