#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests what the formatting step makes of the tools it drives: which exit
# statuses fail the step, which stream carries the reason, and which directories
# it formats.
#
# Both behaviors regress silently. A step that swallows a missing tool ends
# every turn clean while nothing is being formatted; a step that formats one
# directory too many reaches outside the session's own work.
#
# The fixtures replace the real runners with fakes, reached through $HOME the
# way the step reaches the real ones, and stand the step up inside a fake
# dotfiles repo so the second-pass logic has a root to find — no test-only seam
# in the script.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/../scripts/shell-test-framework.sh"

require_commands git

# --- case helpers -----------------------------------------------------------

# Writes one fake runner into the case's fake HOME. The body arrives on stdin so
# each case can write it as a quoted heredoc, where `$PWD` and `$HOME` stay
# literal for the fake itself to expand when the step runs it.
write_runner() { # write_runner <runner name>   (body on stdin)
  local runner="$case_dir/home/.claude/scripts/$1"
  {
    echo '#!/usr/bin/env bash'
    cat
  } > "$runner"
  chmod +x "$runner"
}

# Writes the fake `is-third-party-repo.sh` the step consults about the session's
# repo. The exit status stands in for the verdict: 0 for someone else's
# checkout, 1 for the user's own.
write_classifier() { # write_classifier <exit status>
  local classifier="$case_dir/repo/claude/hooks/is-third-party-repo.sh"
  printf '#!/usr/bin/env bash\nexit %s\n' "$1" > "$classifier"
  chmod +x "$classifier"
}

# Begins a case whose directory holds a fake dotfiles repo carrying the step,
# plus a fake HOME holding a do-nothing fake for each runner the step drives. A
# case overrides only the runner it is about.
begin_step_case() { # begin_step_case <name>
  begin_case "$1"
  mkdir -p "$case_dir/repo/claude/hooks" "$case_dir/home/.claude/scripts"
  cp "$script_dir/format.sh" "$case_dir/repo/claude/hooks/"
  write_classifier 1

  # The step locates the dotfiles repo with git, so the fake one has to be a
  # checkout rather than a bare directory tree.
  git -C "$case_dir/repo" init --quiet

  local runner
  for runner in quiet-prettier.sh quiet-ruff.sh quiet-rustfmt.sh; do
    write_runner "$runner" <<< "exit 0"
  done
}

# Runs the step from the given directory against the case's fake HOME, leaving
# its streams in the case directory as stdout and stderr. Returns the step's own
# exit status, which is the verdict stop_checks.sh reads.
run_step() { # run_step <directory>
  (cd "$1" && HOME="$case_dir/home" "$case_dir/repo/claude/hooks/format.sh") \
    > "$case_dir/stdout" 2> "$case_dir/stderr"
}

# Counts the directories the fake runners were handed, for the cases about how
# many passes the step makes. An unrun runner leaves no log at all.
invocation_count() {
  [ -f "$case_dir/home/invocations" ] || {
    echo 0
    return 0
  }
  grep -c '' < "$case_dir/home/invocations"
}

# How many times a runner was handed exactly the given directory. The passes run
# in parallel, so the log lists them in no fixed order, and the count ignores
# position. Each logged line is compared whole, with symlinks resolved on both
# sides, since a session outside any repo hands over its directory unresolved.
invocations_of() { # invocations_of <directory>
  local logged wanted count=0
  wanted=$(realpath "$1")
  while IFS= read -r logged; do
    [ "$(realpath "$logged")" = "$wanted" ] && count=$((count + 1))
  done < "$case_dir/home/invocations"
  echo "$count"
}

# --- cases ------------------------------------------------------------------

begin_step_case passes-on-findings
write_runner quiet-ruff.sh << 'BODY'
echo "F401 [*] unused import"
exit 1
BODY
run_step "$case_dir/repo"
exit_code=$?

expect "findings leave the step passing" test "$exit_code" -eq 0
expect "findings stay off the halting stream" test ! -s "$case_dir/stderr"
expect "findings stay on the stream stop_checks drops" \
  contains "$(cat "$case_dir/stdout")" "F401"

begin_step_case fails-on-an-unparseable-file
write_runner quiet-ruff.sh << 'BODY'
echo "error: Failed to parse module.py"
exit 2
BODY
run_step "$case_dir/repo"
exit_code=$?

expect "a tool that could not do its job fails the step" \
  test "$exit_code" -ne 0
expect "its reason reaches the halting stream" \
  contains "$(cat "$case_dir/stderr")" "Failed to parse"

# A runner reports a missing tool on its stdout, which stop_checks.sh drops, so
# the step has to move the message to stderr for the user to ever see it.
begin_step_case fails-on-a-missing-ruff
write_runner quiet-ruff.sh << 'BODY'
echo "ruff: command not found"
exit 127
BODY
run_step "$case_dir/repo"
exit_code=$?

expect "a missing ruff fails the step" test "$exit_code" -ne 0
expect "a missing ruff explains itself on the halting stream" \
  contains "$(cat "$case_dir/stderr")" "command not found"

begin_step_case fails-on-a-missing-prettier
write_runner quiet-prettier.sh << 'BODY'
echo "prettier: command not found"
exit 127
BODY
run_step "$case_dir/repo"
exit_code=$?

expect "a missing prettier fails the step" test "$exit_code" -ne 0
expect "a missing prettier explains itself on the halting stream" \
  contains "$(cat "$case_dir/stderr")" "command not found"

# rustfmt reports a file it cannot parse on the breakage level, which has to
# fail the step as a missing tool does.
begin_step_case fails-on-a-broken-rustfmt
write_runner quiet-rustfmt.sh << 'BODY'
echo "error: this file contains an unclosed delimiter"
exit 2
BODY
run_step "$case_dir/repo"
exit_code=$?

expect "a broken rustfmt fails the step" test "$exit_code" -ne 0
expect "a broken rustfmt explains itself on the halting stream" \
  contains "$(cat "$case_dir/stderr")" "unclosed delimiter"

begin_step_case passes-when-the-tools-work
run_step "$case_dir/repo"
exit_code=$?

expect "a clean run passes the step" test "$exit_code" -eq 0
expect "a clean run says nothing on the halting stream" \
  test ! -s "$case_dir/stderr"

# The runners run in parallel, so a break in one does not stop the other. Only
# the first break, in the runners' order, reaches the user, which keeps the
# report readable.
begin_step_case reports-only-the-first-break
write_runner quiet-prettier.sh << 'BODY'
echo "prettier: command not found"
exit 127
BODY
write_runner quiet-ruff.sh << 'BODY'
echo "error: Failed to parse module.py"
exit 2
BODY
run_step "$case_dir/repo"
exit_code=$?

expect "two broken tools fail the step with the first one's status" \
  test "$exit_code" -eq 127
expect "the first break is reported" \
  contains "$(cat "$case_dir/stderr")" "command not found"
expect "and the second is not" \
  not_contains "$(cat "$case_dir/stderr")" "Failed to parse"

begin_step_case formats-the-dotfiles-repo-from-outside
write_runner quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
mkdir -p "$case_dir/project"
run_step "$case_dir/project"

expect "a session outside the repo makes two passes" \
  test "$(invocation_count)" -eq 2
expect "with no repo to anchor on, one pass covers the directory" \
  test "$(invocations_of "$case_dir/project")" -eq 1
expect "the other pass targets the dotfiles repo" \
  test "$(invocations_of "$case_dir/repo")" -eq 1

begin_step_case formats-the-repo-root-once
write_runner quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
run_step "$case_dir/repo"

expect "a session at the repo root makes one pass" \
  test "$(invocation_count)" -eq 1

# A session's directory can sit below its repo root, and a pass over that
# subtree alone would skip whatever the turn edited elsewhere in the repo.
begin_step_case formats-from-the-session-repo-root
write_runner quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
mkdir -p "$case_dir/project/nested"
git -C "$case_dir/project" init --quiet
run_step "$case_dir/project/nested"

expect "a session below its repo root formats from the root" \
  test "$(invocations_of "$case_dir/project")" -eq 1

# A worktree is a checkout of its own, so the first pass already covers it; a
# second pass would reach into the checkout it branched from. The fixture makes
# a real worktree because the step asks git where the session's repo starts: git
# names a real worktree as its own root, where a plain subdirectory of the repo
# would name the parent checkout.
begin_step_case formats-a-worktree-once
write_runner quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
worktree_dir="$case_dir/repo/.claude/worktrees/lane"
# `git worktree add` needs a commit to branch from. The identity and signing
# settings come from flags so the case does not depend on the user's git config.
git -C "$case_dir/repo" -c user.name=test -c user.email=test@example.com \
  -c commit.gpgsign=false commit --quiet --allow-empty -m "fixture"
git -C "$case_dir/repo" worktree add --quiet "$worktree_dir"
run_step "$worktree_dir"

expect "a session in a worktree makes one pass" \
  test "$(invocation_count)" -eq 1

# Someone else's checkout keeps its own formatting. The dotfiles pass has to
# survive that skip, since a session working there can still edit dotfiles.
begin_step_case skips-someone-elses-checkout
write_classifier 0
write_runner quiet-ruff.sh << 'BODY'
echo "$PWD" >> "$HOME/invocations"
exit 0
BODY
mkdir -p "$case_dir/project"
git -C "$case_dir/project" init --quiet
run_step "$case_dir/project"

expect "a session in someone else's checkout makes one pass" \
  test "$(invocation_count)" -eq 1
expect_equal "the pass that survives is the dotfiles one" \
  "$(head -1 "$case_dir/home/invocations")" "$(realpath "$case_dir/repo")"

# The passes run in parallel, so a tool broken in both passes breaks twice; the
# report names the break once.
begin_step_case reports-a-break-in-both-passes-once
write_runner quiet-prettier.sh << 'BODY'
echo "prettier: command not found in $PWD"
exit 127
BODY
mkdir -p "$case_dir/project"
run_step "$case_dir/project"
exit_code=$?

expect "a tool broken in both passes fails the step" test "$exit_code" -ne 0
expect "and is reported once" \
  test "$(grep -c 'command not found' "$case_dir/stderr")" -eq 1

# --- summary ----------------------------------------------------------------

exit_with_summary
