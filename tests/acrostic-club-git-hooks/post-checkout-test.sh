#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for `acrostic-club-git-hooks/post-checkout`. The cases that call the
# hook's functions build plain directories. The rest build a superproject with a
# local submodule, link the hook into it as install.sh does, and let git run it.

script_dir=$(cd "$(dirname "$0")" && pwd)

# Each sourced file's path is spelled out from `$script_dir`, so shellcheck can
# follow it and see what the file defines.
source "$script_dir/../../claude/scripts/shell-test-framework.sh"
source "$script_dir/../../acrostic-club-git-hooks/post-checkout"

# Each fixture links the hook into its own hooks directory, as install.sh does
# for acrostic-club.
hook="$script_dir/../../acrostic-club-git-hooks/post-checkout"

require_commands git

# Keep this machine's git configuration away from the fixtures, since a global
# setting such as commit signing would change what their git commands do. Give
# their commits an author too.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# --- helpers ----------------------------------------------------------------

# Prints `null` or `other`, by whether `is_null_ref` accepts <ref>. Comparing
# words with expect_equal makes a failure say which verdict came back.
ref_kind() { # ref_kind <ref>
  if is_null_ref "$1"; then
    echo null
  else
    echo other
  fi
}

# Builds a superproject at <superproject> holding one submodule, at
# <submodule_path>, cloned from <origin>: a directory the case has already
# filled with files. Then links the hook into the superproject's hooks.
#
# Usage: build_superproject <superproject> <origin> <submodule_path>
build_superproject() {
  git -C "$2" init --quiet --initial-branch=main
  git -C "$2" add --all
  git -C "$2" commit --quiet --message "Add data"

  git init --quiet --initial-branch=main "$1"
  # Git refuses to clone a submodule from a local path unless told otherwise.
  git -C "$1" -c protocol.file.allow=always submodule add --quiet "$2" "$3"
  git -C "$1" commit --quiet --message "Add submodule"

  ln -s "$hook" "$1/.git/hooks/post-checkout"
}

# --- recognizing the null ref -----------------------------------------------

begin_case null_ref_is_recognized_at_either_hash_length
# `%040d` pads the number 0 with zeros to 40 digits.
expect_equal "recognizes SHA-1's" "$(ref_kind "$(printf '%040d' 0)")" null
expect_equal "recognizes SHA-256's" "$(ref_kind "$(printf '%064d' 0)")" null

begin_case other_refs_are_not_null
expect_equal "rejects a commit's name" \
  "$(ref_kind 3f786850e387550fdab836ed7e6dc881de23001b)" other
expect_equal "rejects an empty argument" "$(ref_kind "")" other

# --- cloning one submodule --------------------------------------------------

begin_case files_are_cloned_without_the_git_pointer
main_copy="$case_dir/main/submodules/quotes"
worktree_copy="$case_dir/worktree/submodules/quotes"
mkdir -p "$main_copy" "$worktree_copy"
echo "Brevity is the soul of wit." > "$main_copy/quotes.csv"
echo "*.csv binary" > "$main_copy/.gitattributes"
echo "gitdir: ../../.git/modules/quotes" > "$main_copy/.git"

clone_submodule_files "$case_dir/main" "$case_dir/worktree" submodules/quotes \
  > /dev/null

expect "clones a file" \
  cmp -s "$main_copy/quotes.csv" "$worktree_copy/quotes.csv"
expect "clones a hidden file" \
  cmp -s "$main_copy/.gitattributes" "$worktree_copy/.gitattributes"
expect "leaves the git pointer behind" test ! -e "$worktree_copy/.git"

begin_case worktree_copy_holding_files_is_left_alone
main_copy="$case_dir/main/submodules/quotes"
worktree_copy="$case_dir/worktree/submodules/quotes"
mkdir -p "$main_copy" "$worktree_copy"
echo "from the main checkout" > "$main_copy/quotes.csv"
echo "already here" > "$worktree_copy/quotes.csv"

output=$(clone_submodule_files "$case_dir/main" "$case_dir/worktree" \
  submodules/quotes 2>&1)

expect_equal "keeps the worktree's file" \
  "$(cat "$worktree_copy/quotes.csv")" "already here"
expect_equal "says nothing" "$output" ""

begin_case empty_main_copy_is_reported
# Both copies are empty, as when the main checkout never fetched the submodule.
mkdir -p "$case_dir/main/submodules/quotes" \
  "$case_dir/worktree/submodules/quotes"

output=$(clone_submodule_files "$case_dir/main" "$case_dir/worktree" \
  submodules/quotes 2>&1)
exit_status=$?

expect_equal "fails" "$exit_status" 1
expect "says the main copy has no files" contains "$output" "no files"
expect_equal "leaves the worktree's copy empty" \
  "$(ls -A "$case_dir/worktree/submodules/quotes")" ""

begin_case failed_copy_is_reported
main_copy="$case_dir/main/submodules/quotes"
mkdir -p "$main_copy" "$case_dir/worktree/submodules/quotes"
echo "Brevity is the soul of wit." > "$main_copy/quotes.csv"
chmod 000 "$main_copy/quotes.csv" # unreadable, so cp fails on it

output=$(clone_submodule_files "$case_dir/main" "$case_dir/worktree" \
  submodules/quotes 2>&1)
exit_status=$?

expect_equal "fails" "$exit_status" 1
expect "names the submodule" \
  contains "$output" "could not clone submodules/quotes"

# --- the hook as git runs it ------------------------------------------------

begin_case new_worktree_receives_the_submodule_files
mkdir -p "$case_dir/origin"
echo "Brevity is the soul of wit." > "$case_dir/origin/quotes.csv"
build_superproject "$case_dir/superproject" "$case_dir/origin" submodules/quotes

output=$(git -C "$case_dir/superproject" worktree add --quiet \
  "$case_dir/worktree" 2>&1)

expect "clones the file into the worktree" \
  cmp -s "$case_dir/origin/quotes.csv" \
  "$case_dir/worktree/submodules/quotes/quotes.csv"
expect "reports the clone" contains "$output" "cloned submodules/quotes"
# Git sees no change at all, not even an untracked file.
expect_equal "leaves git status clean" \
  "$(git -C "$case_dir/worktree" status --porcelain)" ""

begin_case failed_clone_still_creates_the_worktree
mkdir -p "$case_dir/origin"
echo "Brevity is the soul of wit." > "$case_dir/origin/quotes.csv"
build_superproject "$case_dir/superproject" "$case_dir/origin" submodules/quotes
chmod 000 "$case_dir/superproject/submodules/quotes/quotes.csv"

output=$(git -C "$case_dir/superproject" worktree add --quiet \
  "$case_dir/worktree" 2>&1)
exit_status=$?

expect_equal "git worktree add succeeds" "$exit_status" 0
expect "reports the failed clone" contains "$output" "could not clone"

begin_case fresh_clone_is_left_alone
mkdir -p "$case_dir/origin"
echo "Brevity is the soul of wit." > "$case_dir/origin/quotes.csv"
build_superproject "$case_dir/superproject" "$case_dir/origin" submodules/quotes
# A clone made from this template gets the hook, and runs it with the null ref
# while the clone's submodule is still empty.
mkdir -p "$case_dir/template/hooks"
ln -s "$hook" "$case_dir/template/hooks/post-checkout"

output=$(git clone --quiet --template="$case_dir/template" \
  "$case_dir/superproject" "$case_dir/clone" 2>&1)

expect "says nothing" not_contains "$output" "post-checkout"
expect_equal "leaves the submodule empty" \
  "$(ls -A "$case_dir/clone/submodules/quotes")" ""

begin_case branch_switch_in_a_worktree_is_ignored
mkdir -p "$case_dir/origin"
echo "Brevity is the soul of wit." > "$case_dir/origin/quotes.csv"
build_superproject "$case_dir/superproject" "$case_dir/origin" submodules/quotes
git -C "$case_dir/superproject" worktree add --quiet "$case_dir/worktree" \
  > /dev/null 2>&1
rm "$case_dir/worktree/submodules/quotes/quotes.csv"

output=$(git -C "$case_dir/worktree" switch --quiet --create feature 2>&1)

expect "says nothing" not_contains "$output" "post-checkout"
expect_equal "leaves the emptied copy empty" \
  "$(ls -A "$case_dir/worktree/submodules/quotes")" ""

exit_with_summary
