#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests what the formatting step makes of the tools it drives: which exit
# statuses fail the step, which stream carries the reason, and which
# directories it formats.
#
# Both behaviors regress silently. A step that swallows a missing tool ends
# every turn clean while nothing is being formatted; a step that formats one
# directory too many reaches outside the session's own work.
#
# The fixtures replace the real runners with fakes, reached through $HOME the
# way the step reaches the real ones, and stand the step up inside a fake
# dotfiles repo so the second-pass logic has a root to find — no test-only
# seam in the script.

script_dir=$(cd "$(dirname "$0")" && pwd)

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

# Writes one fake runner into a fixture's fake HOME. The body arrives on stdin
# so each case can write it as a quoted heredoc, where `$PWD` and `$HOME` stay
# literal for the fake itself to expand when the step runs it.
write_runner() { # write_runner <fixture> <runner name>   (body on stdin)
  local runner="$1/home/.claude/scripts/$2"
  {
    echo '#!/usr/bin/env bash'
    cat
  } > "$runner"
  chmod +x "$runner"
}

# Builds a fixture: a fake dotfiles repo holding the step, plus a fake HOME
# holding a do-nothing fake for each runner the step drives. A case overrides
# only the runner it is about. Prints the fixture directory, which holds repo/
# and home/.
make_fixture() { # make_fixture  -> prints the fixture directory
  local fixture runner
  fixture=$(mktemp -d "$test_root/case.XXXXXX")
  mkdir -p "$fixture/repo/claude/hooks" "$fixture/home/.claude/scripts"
  cp "$script_dir/format.sh" "$fixture/repo/claude/hooks/"

  # The step locates the dotfiles repo with git, so the fake one has to be a
  # checkout rather than a bare directory tree.
  git -C "$fixture/repo" init --quiet

  for runner in quiet-prettier.sh quiet-ruff.sh; do
    write_runner "$fixture" "$runner" <<< "exit 0"
  done
  echo "$fixture"
}

# Runs the step from the given directory against the fixture's fake HOME,
# leaving its streams in the fixture as stdout and stderr. Returns the step's
# own exit status, which is the verdict stop_checks.sh reads.
run_step() { # run_step <fixture> <directory>
  (cd "$2" && HOME="$1/home" "$1/repo/claude/hooks/format.sh") \
    > "$1/stdout" 2> "$1/stderr"
}

# Counts the directories the fake runners were handed, for the cases about how
# many passes the step makes. An unrun runner leaves no log at all.
invocation_count() { # invocation_count <fixture>
  [ -f "$1/home/invocations" ] || {
    echo 0
    return 0
  }
  grep -c '' < "$1/home/invocations"
}

# --- a tool's findings are not the step's failure ---------------------------

fixture=$(make_fixture)
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "F401 [*] unused import"
exit 1
BODY
run_step "$fixture" "$fixture/repo"
findings_status=$?

expect "findings leave the step passing" test "$findings_status" -eq 0
expect "findings stay off the halting stream" test ! -s "$fixture/stderr"
expect "findings stay on the stream stop_checks drops" \
  contains "$(cat "$fixture/stdout")" "F401"

# --- a tool that cannot parse a file fails the step -------------------------

fixture=$(make_fixture)
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "error: Failed to parse module.py"
exit 2
BODY
run_step "$fixture" "$fixture/repo"
unparseable_status=$?

expect "a tool that could not do its job fails the step" \
  test "$unparseable_status" -ne 0
expect "its reason reaches the halting stream" \
  contains "$(cat "$fixture/stderr")" "Failed to parse"

# --- a missing tool fails the step rather than going unnoticed --------------

# A runner reports a missing tool on its stdout, which stop_checks.sh drops, so
# the step has to move the message to stderr for the user to ever see it.
fixture=$(make_fixture)
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "ruff: command not found"
exit 127
BODY
run_step "$fixture" "$fixture/repo"
missing_ruff_status=$?

expect "a missing ruff fails the step" test "$missing_ruff_status" -ne 0
expect "a missing ruff explains itself on the halting stream" \
  contains "$(cat "$fixture/stderr")" "command not found"

fixture=$(make_fixture)
write_runner "$fixture" quiet-prettier.sh << 'BODY'
echo "prettier: command not found"
exit 127
BODY
run_step "$fixture" "$fixture/repo"
missing_prettier_status=$?

expect "a missing prettier fails the step" test "$missing_prettier_status" -ne 0
expect "a missing prettier explains itself on the halting stream" \
  contains "$(cat "$fixture/stderr")" "command not found"

# --- working tools leave the turn alone -------------------------------------

fixture=$(make_fixture)
run_step "$fixture" "$fixture/repo"
clean_status=$?

expect "a clean run passes the step" test "$clean_status" -eq 0
expect "a clean run says nothing on the halting stream" \
  test ! -s "$fixture/stderr"

# --- a broken tool stops the ones after it ----------------------------------

# prettier runs first, so a break there must leave ruff unrun rather than
# pressing on with a formatter chain that is already failing.
fixture=$(make_fixture)
write_runner "$fixture" quiet-prettier.sh << 'BODY'
echo "prettier: command not found"
exit 127
BODY
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
run_step "$fixture" "$fixture/repo"

expect "a broken tool stops the runners after it" \
  test "$(invocation_count "$fixture")" -eq 0

# --- a session outside the repo formats the dotfiles repo too ---------------

fixture=$(make_fixture)
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
mkdir -p "$fixture/project"
run_step "$fixture" "$fixture/project"

expect "a session outside the repo makes two passes" \
  test "$(invocation_count "$fixture")" -eq 2
expect "the second pass targets the dotfiles repo" \
  contains "$(cat "$fixture/home/invocations")" "$(realpath "$fixture/repo")"

# --- a session inside the repo formats it once ------------------------------

fixture=$(make_fixture)
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
run_step "$fixture" "$fixture/repo"

expect "a session at the repo root makes one pass" \
  test "$(invocation_count "$fixture")" -eq 1

# A worktree is a copy of the repo, so formatting the current directory already
# covers it; a second pass would reach into the checkout it branched from.
fixture=$(make_fixture)
write_runner "$fixture" quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
mkdir -p "$fixture/repo/.claude/worktrees/lane"
run_step "$fixture" "$fixture/repo/.claude/worktrees/lane"

expect "a session in a worktree makes one pass" \
  test "$(invocation_count "$fixture")" -eq 1

# --- a broken tool stops the step before the second pass --------------------

fixture=$(make_fixture)
write_runner "$fixture" quiet-prettier.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
echo "prettier: command not found"
exit 127
BODY
mkdir -p "$fixture/project"
run_step "$fixture" "$fixture/project"

expect "a broken tool is not run over a second directory" \
  test "$(invocation_count "$fixture")" -eq 1

# --- summary ----------------------------------------------------------------

if [ "$failure_count" -ne 0 ]; then
  echo "format-test: $failure_count assertion(s) failed" >&2
  exit 1
fi
echo "format-test: all assertions passed"
