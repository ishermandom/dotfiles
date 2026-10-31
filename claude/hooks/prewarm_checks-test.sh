#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests what prewarm_checks.sh runs when a session enters a worktree, and where
# it runs it.
#
# The fixtures replace the real checks with fakes, as stop_checks-test.sh does:
# prewarm_checks.sh resolves its steps from its own directory, so a copy of it
# beside a fake for each step runs them. macOS scans every new script the first
# time it runs, which makes each fixture cost a few tenths of a second, so each
# case asserts everything one run can show.

script_dir=$(cd "$(dirname "$0")" && pwd)
prewarm_checks="$script_dir/prewarm_checks.sh"

. "$script_dir/../scripts/shell-test-framework.sh"

require_commands jq

# --- helpers ----------------------------------------------------------------

write_step() { # write_step <steps dir> <step name> <body>
  printf '#!/usr/bin/env bash\n%s\n' "$3" > "$1/$2"
  chmod +x "$1/$2"
}

# Builds the case's fixture: a directory to stand for the entered worktree, at
# `$worktree`, and a copy of prewarm_checks.sh in `$steps` beside a fake for
# each step it might run. Each fake logs its name and working directory to
# `$case_dir/run.log`. A case overrides only the steps it is about.
make_fixture() {
  worktree="$case_dir/worktree"
  steps="$case_dir/steps"
  mkdir -p "$worktree" "$steps"
  cp "$prewarm_checks" "$steps/"
  local step
  for step in format.sh mypy-check.sh run_tests.sh ruff-lint.sh; do
    write_step "$steps" "$step" "echo \"$step \$PWD\" >> '$case_dir/run.log'"
  done

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

# The log matching exactly also shows formatting was left to the Stop hook.
expect_equal \
  "the checks run in the entered worktree, in the Stop hook's order" \
  "$(cat "$case_dir/run.log")" "mypy-check.sh $worktree
run_tests.sh $worktree
ruff-lint.sh $worktree"

# --- failing checks ---------------------------------------------------------

begin_case "failing-checks"
make_fixture
write_step "$steps" "mypy-check.sh" "exit 1"
write_step "$steps" "run_tests.sh" 'echo "1 failed, 30 passed"
echo "warning: slow test" >&2
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

# --- summary ----------------------------------------------------------------

exit_with_summary
