#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Test suite for the dotfiles repo — the Python unit tests under claude/hooks,
# claude/scripts, and chromium, plus the standalone shell tests, which sit
# beside the code they cover or under tests/. Run directly, or via
# ~/.claude/scripts/quiet-tests.sh (which the Stop test hook invokes). Honors
# PYTEST_ADDOPTS, which the quiet runner sets to --tb=short. Test modules import
# the code they cover by bare name, as the root pyproject.toml explains.
# Arguments are forwarded to pytest; naming a path narrows the run to that path,
# and to pytest alone — the shell tests take no arguments.
#
# A run from the Stop hook, which sets PYTEST_FROM_HOOK, leaves out the shell
# tests and the Python tests marked `slow`. Every other run includes them.

# Resolve the test directories against the script's own location so the suite
# runs identically regardless of the caller's working directory; per the testing
# convention we never cd. pyproject.toml's testpaths would be the tidier home
# for the list, but pytest honors testpaths only when invoked from the rootdir.
root="$(dirname "$0")"

# The suite's directories are a default, not a floor: a path the caller names
# stands on its own, so a path forwarded from ~/.claude/scripts/quiet-tests.sh
# narrows the run rather than adding to everything. Options carry no such
# meaning, so `-k expression` still runs against the whole suite.
#
# Recognize a path by whether it exists rather than by a leading dash — an
# option's value is a bare word too, and mistaking `expression` for a path would
# silently leave pytest collecting from the caller's directory.
names_test_path=false
for argument in "$@"; do
  # `${argument%%::*}` drops the selector from a node id, leaving the file.
  if [ -e "${argument%%::*}" ]; then
    names_test_path=true
    break
  fi
done

shell_test_status=0
if [ "$names_test_path" = false ]; then
  # The shell tests are standalone executables, which pytest cannot collect, so
  # the suite runs them itself. They go first so a passing run still ends on
  # pytest's summary — the one line quiet-tests.sh keeps on success.
  #
  # The Stop hook's run skips them: together they take seconds, too long to pay
  # at the end of every turn. `:-` reads an unset variable as empty.
  #
  # Each builds its fixtures under a temporary directory of its own, so they run
  # in parallel, each into a file of its own. The files print in the order the
  # tests are listed, so their reports never interleave. The trailing `&` runs a
  # test in the background, `$!` is its process ID, and `[-1]` is an array's
  # last element.
  #
  # TODO: an interrupt stops this script but leaves the running tests to finish
  # on their own, since a script's background jobs ignore Ctrl-C.
  if [ -z "${PYTEST_FROM_HOOK:-}" ]; then
    shell_tests=("$root"/*-test.sh "$root"/claude/hooks/*-test.sh
      "$root"/claude/scripts/*-test.sh "$root"/tests/*/*-test.sh)
    shell_test_outputs=()
    shell_test_pids=()
    for shell_test in "${shell_tests[@]}"; do
      # An unmatched glob stays literal in bash, so -e skips the pattern itself.
      [ -e "$shell_test" ] || continue
      shell_test_outputs+=("$(mktemp)")
      "$shell_test" > "${shell_test_outputs[-1]}" 2>&1 &
      shell_test_pids+=($!)
    done

    # `${!shell_test_pids[@]}` lists the array's indices, so each test's report
    # prints beside its own exit status.
    for index in "${!shell_test_pids[@]}"; do
      wait "${shell_test_pids[$index]}" || shell_test_status=1
      cat "${shell_test_outputs[$index]}"
    done
    rm -f "${shell_test_outputs[@]}"
  fi

  # `set --` puts the suite's directories ahead of the caller's options.
  set -- "$root/claude/hooks" "$root/claude/scripts" "$root/chromium" "$@"
fi

# The Stop hook's run also leaves out the Python tests marked `slow`, a mark
# pyproject.toml defines. The flags sit in an array so that, empty, it adds no
# argument at all.
hook_args=()
if [ -n "${PYTEST_FROM_HOOK:-}" ]; then
  hook_args=(-m "not slow")
fi

# `uv run --project` uses this checkout's own `.venv`, building it from uv.lock
# when absent — so a fresh clone or a new worktree runs green with no setup
# step, and each worktree tests against its own environment rather than
# whichever venv the caller's shell activated.
uv run --project "$root" pytest "${hook_args[@]}" "$@"
pytest_status=$?

# Either half failing fails the run.
[ $shell_test_status -ne 0 ] && exit 1
exit $pytest_status
