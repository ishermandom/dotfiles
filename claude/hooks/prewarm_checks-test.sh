#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests what prewarm_checks.sh runs when a session enters a worktree, and where
# it runs it.
#
# The fixtures replace the real checks with fakes, as stop_checks-test.sh does:
# prewarm_checks.sh resolves its steps from its own directory, so a copy of it
# beside a fake for each step runs them.

script_dir=$(cd "$(dirname "$0")" && pwd)
prewarm_checks="$script_dir/prewarm_checks.sh"

source "$script_dir/../scripts/shell-test-framework.sh"

require_commands jq

# --- helpers ----------------------------------------------------------------

write_step() { # write_step <steps dir> <step name> <body>
  stub_executable "$1/$2" <<< "$3"
}

# Builds the case's fixture: a directory to stand for the entered worktree, at
# `$worktree`, and a copy of prewarm_checks.sh in `$steps` beside a fake for
# each step it might run. Each fake logs its name and working directory to
# `$case_dir/run.log`. A case overrides only the steps it is about.
#
# prewarm_checks.sh looks for the prettier runner in the directory beside its
# own, so the runner's fake sits in `$scripts`, beside `$steps`. The fake logs
# its arguments and working directory to a file of its own,
# `$case_dir/prettier.log`: prewarm_checks.sh starts the runner alongside the
# checks, so the runner's line could land anywhere in their log.
make_fixture() {
  worktree="$case_dir/worktree"
  steps="$case_dir/steps"
  scripts="$case_dir/scripts"
  mkdir -p "$worktree" "$steps"
  place_executable "$prewarm_checks" "$steps/prewarm_checks.sh"
  local step
  for step in format.sh mypy-check.sh run_tests.sh ruff-lint.sh \
    clippy-lint.sh; do
    write_step "$steps" "$step" "echo \"$step \$PWD\" >> '$case_dir/run.log'"
  done
  write_step "$scripts" "quiet-prettier.sh" \
    "echo \"quiet-prettier.sh \$* \$PWD\" >> '$case_dir/prettier.log'"

  # Exit 1 is its verdict for the user's own repo, which every case but one is
  # about.
  write_step "$steps" "is-third-party-repo.sh" "exit 1"
}

# Runs the fixture's prewarm_checks.sh as Claude Code does after entering
# `$worktree`, handing it the worktree in the input's `cwd`. It starts from the
# case directory, so only the input can point it at the worktree.
prewarm() { # prewarm  -> prints whatever the hook printed
  printf '{"cwd": "%s"}' "$worktree" \
    | (cd "$case_dir" && "$steps/prewarm_checks.sh" 2>&1)
}

# --- a prewarm in the user's own worktree -----------------------------------

begin_case "own-worktree"
make_fixture
prewarm > /dev/null

# The log matching exactly also shows format.sh was left to the Stop hook.
expect_equal \
  "the checks run in the entered worktree, in the Stop hook's order" \
  "$(cat "$case_dir/run.log")" "mypy-check.sh $worktree
run_tests.sh $worktree
ruff-lint.sh $worktree
clippy-lint.sh $worktree"
expect_equal "prettier checks the entered worktree without rewriting it" \
  "$(cat "$case_dir/prettier.log")" "quiet-prettier.sh --check $worktree"

# --- failing checks ---------------------------------------------------------

begin_case "failing-checks"
make_fixture
write_step "$steps" "mypy-check.sh" "exit 1"
write_step "$steps" "run_tests.sh" 'echo "1 failed, 30 passed"
echo "warning: slow test" >&2
exit 1'
write_step "$scripts" "quiet-prettier.sh" 'echo "[warn] notes.md"
exit 1'
output=$(prewarm)

expect "the checks after a failing one still run" \
  contains "$(cat "$case_dir/run.log")" "ruff-lint.sh"
expect_equal "the checks' output stays out of the session" "$output" ""

# --- someone else's checkout is left cold -----------------------------------

# The Stop hook never runs the checks there, so there is nothing to prewarm, and
# running them would execute a project the session does not own.
begin_case "third-party"
make_fixture
write_step "$steps" "is-third-party-repo.sh" "exit 0"
prewarm > /dev/null

expect "someone else's checkout runs no checks" test ! -e "$case_dir/run.log"
expect "and no prettier check" test ! -e "$case_dir/prettier.log"

# --- summary ----------------------------------------------------------------

exit_with_summary
