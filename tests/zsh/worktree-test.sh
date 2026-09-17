#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for `zsh/.worktree.zsh`. Each case builds a scratch code tree of project
# directories, points `WORKTREE_CODE_ROOT` at it, and asserts on where `wt`
# lands. A stubbed `zed` reports the directory it was handed rather than opening
# anything.

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root="$script_dir/../.."
command_file="$repo_root/zsh/.worktree.zsh"

. "$repo_root/claude/scripts/shell-test-framework.sh"

require_commands zsh

# --- zed stub ---------------------------------------------------------------

mkdir "$test_script_root/bin"
cat > "$test_script_root/bin/zed" << 'STUB'
#!/usr/bin/env bash
# Reports the directory it was asked to open, instead of starting an editor.
echo "zed opened $1"
STUB
chmod +x "$test_script_root/bin/zed"

# --- helpers ----------------------------------------------------------------

# Creates a worktree directory for the named project in the case's code tree,
# carrying the `.git` file that marks a real checkout.
make_worktree() { # make_worktree <project> <name>
  local worktree="$case_dir/$1/.claude/worktrees/$2"
  mkdir -p "$worktree"
  touch "$worktree/.git"
}

# Sources `.worktree.zsh` with the case's code tree as the code root, runs the
# given zsh snippet against it, and prints everything the snippet wrote to
# either stream.
#
# `compinit` has to run first, because `.worktree.zsh` registers a completion.
# `-d` keeps the completion dump inside each test case.
#
# Dropping `FPATH` keeps the `compinit` run independent of the shell
# environment. `brew shellenv` exports an `FPATH` naming Homebrew's completion
# directory, which belongs to whichever account installed Homebrew, and compinit
# distrusts a completion directory that belongs to another account: it stops to
# ask what to do, finds no terminal to answer on, and gives up, leaving
# `compdef` undefined. Without `FPATH`, compinit sees only the root-owned system
# directories.
run_zsh() { # run_zsh <snippet>
  env -u FPATH WORKTREE_CODE_ROOT="$case_dir" \
    PATH="$test_script_root/bin:$PATH" \
    zsh -c "autoload -Uz compinit
      compinit -d '$case_dir/zcompdump'
      source '$command_file'
      $1" 2>&1
}

# --- resolving a name -------------------------------------------------------

begin_case unique_name_opens_the_worktree
make_worktree bridge squeezes
output=$(run_zsh "wt squeezes")
expect_equal "opens the worktree, found by name alone" "$output" \
  "zed opened $case_dir/bridge/.claude/worktrees/squeezes"

begin_case project_without_worktrees_is_skipped
mkdir -p "$case_dir/cargo" # a project holding no worktrees at all
make_worktree bridge squeezes
output=$(run_zsh "wt squeezes")
expect_equal "opens the worktree, ignoring the project that has none" \
  "$output" "zed opened $case_dir/bridge/.claude/worktrees/squeezes"

begin_case directory_that_is_not_a_checkout_is_skipped
# `feature` is a plain directory rather than a checkout, holding the worktree
# `feature/parser` one level below it.
make_worktree bridge feature/parser
output=$(run_zsh "wt feature")
expect "names what it could not find" contains "$output" "feature"
expect "opens nothing" not_contains "$output" "zed opened"

# TODO: This test documents a limitation of the current behavior, rather than
# intended behavior.
begin_case worktree_named_with_a_slash_is_not_found
# The listing reaches exactly one level under `worktrees/`, so a worktree nested
# below that is currently out of reach.
make_worktree bridge feature/parser
output=$(run_zsh "wt parser")
expect "names what it could not find" contains "$output" "parser"
expect "opens nothing" not_contains "$output" "zed opened"

begin_case shared_name_is_refused
make_worktree bridge review-ui
make_worktree crosswords review-ui
output=$(run_zsh "wt review-ui")
expect "names the bridge worktree" contains "$output" "bridge/review-ui"
expect "names the crosswords worktree" contains "$output" "crosswords/review-ui"
expect "opens neither" not_contains "$output" "zed opened"

begin_case qualified_name_settles_a_shared_name
make_worktree bridge review-ui
make_worktree crosswords review-ui
output=$(run_zsh "wt crosswords/review-ui")
expect_equal "opens the crosswords worktree" "$output" \
  "zed opened $case_dir/crosswords/.claude/worktrees/review-ui"

begin_case unknown_name_is_reported
make_worktree bridge squeezes
output=$(run_zsh "wt nonexistent")
expect "names what it could not find" contains "$output" "nonexistent"
expect "opens nothing" not_contains "$output" "zed opened"

begin_case empty_code_tree_reports_no_match
# No project is created here at all: a code tree with nothing in it still
# reports a plain "no worktree named ...", rather than failing.
output=$(run_zsh "wt squeezes")
expect "names what it could not find" contains "$output" "squeezes"
expect "opens nothing" not_contains "$output" "zed opened"

begin_case missing_argument_prints_usage
make_worktree bridge squeezes
output=$(run_zsh "wt")
expect "prints usage" contains "$output" "usage: wt"
expect "opens nothing" not_contains "$output" "zed opened"

# --- what completion offers -------------------------------------------------
#
# Driving zsh's completion for real needs a pseudo-terminal, which would be
# fragile. These cases instead directly call `_worktree_candidates`, which holds
# the whole bare-or-qualified policy. `_wt`, the completion function wrapped
# around it, adds nothing but a `compadd` call.

begin_case unique_names_are_offered_bare
make_worktree bridge squeezes
make_worktree dotfiles project-venv
output=$(run_zsh "_worktree_candidates")
expect "offers the bridge worktree" contains "$output" "squeezes"
expect "offers the dotfiles worktree" contains "$output" "project-venv"
expect "leaves a unique name bare" not_contains "$output" "bridge/"

begin_case shared_names_are_offered_qualified
make_worktree bridge review-ui
make_worktree crosswords review-ui
make_worktree bridge squeezes
output=$(run_zsh "_worktree_candidates")
expect "qualifies the bridge worktree" contains "$output" "bridge/review-ui"
expect "qualifies the crosswords worktree" \
  contains "$output" "crosswords/review-ui"
expect "leaves the unique name bare" not_contains "$output" "bridge/squeezes"

exit_with_summary
