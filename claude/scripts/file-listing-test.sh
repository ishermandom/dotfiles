#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for file-listing.sh.
#
# `list_unignored_files` lists tracked and untracked files alike, leaves out
# what git ignores, passes an unusual name through whole, and fails outside a
# repo. `find_crate_manifests` finds a crate at any depth under the current
# directory, and leaves out a deleted manifest and a crate elsewhere in the
# repo; outside a repo, only a crate at the current directory counts.
#
# The cases run the real git. None needs cargo, since only where a manifest sits
# matters, never what it says.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/shell-test-framework.sh"
source "$script_dir/file-listing.sh"

require_commands git

# --- case helpers -----------------------------------------------------------

# Writes an empty file at <path>, creating its directory.
make_file() { # make_file <path>
  mkdir -p "$(dirname "$1")"
  touch "$1"
}

# Lists the files matching <pathspec> from <directory>, one per line. The
# listing is sorted, since its order means nothing: git lists untracked files
# before tracked ones.
files_from() { # files_from <directory> <pathspec>...
  local directory=$1
  shift
  (cd "$directory" && list_unignored_files "$@") | tr '\0' '\n' | sort
}

# Lists the crates' manifests found from <directory>, one per line, sorted for
# the same reason.
crates_from() { # crates_from <directory>
  (cd "$1" && find_crate_manifests && printf '%s\n' "${crate_manifests[@]}") \
    | sort
}

# --- list_unignored_files ---------------------------------------------------

begin_case tracked-and-untracked-files-are-both-listed
git -C "$case_dir" init --quiet
make_file "$case_dir/tracked.md"
git -C "$case_dir" add tracked.md
make_file "$case_dir/untracked.md"

expect_equal "lists both" "$(files_from "$case_dir" '*.md')" "tracked.md
untracked.md"

begin_case an-ignored-file-is-left-out
git -C "$case_dir" init --quiet
echo "build/" > "$case_dir/.gitignore"
make_file "$case_dir/build/notes.md"
make_file "$case_dir/notes.md"

expect_equal "lists only the file git does not ignore" \
  "$(files_from "$case_dir" '*.md')" "notes.md"

begin_case an-unusual-name-arrives-whole
git -C "$case_dir" init --quiet
make_file "$case_dir/café/notes.md"

expect_equal "lists the name unquoted" \
  "$(files_from "$case_dir" '*.md')" "café/notes.md"

begin_case outside-a-repo-the-listing-fails
make_file "$case_dir/notes.md"
listing=$(cd "$case_dir" && list_unignored_files '*.md')
exit_code=$?

expect "fails, so the caller can fall back" test "$exit_code" -ne 0
expect_equal "lists nothing" "$listing" ""

# --- find_crate_manifests ---------------------------------------------------

begin_case no-crate-finds-nothing
git -C "$case_dir" init --quiet

expect_equal "finds nothing" "$(crates_from "$case_dir")" ""

begin_case crates-at-any-depth-are-found
git -C "$case_dir" init --quiet
make_file "$case_dir/Cargo.toml"
make_file "$case_dir/tools/parser/Cargo.toml"

expect_equal "finds both, relative to the current directory" \
  "$(crates_from "$case_dir")" "Cargo.toml
tools/parser/Cargo.toml"

begin_case a-deleted-manifest-is-left-out
git -C "$case_dir" init --quiet
make_file "$case_dir/tools/Cargo.toml"
git -C "$case_dir" add tools
rm "$case_dir/tools/Cargo.toml"

expect_equal "finds nothing, though git still lists the manifest" \
  "$(crates_from "$case_dir")" ""

begin_case a-crate-elsewhere-in-the-repo-is-left-out
git -C "$case_dir" init --quiet
make_file "$case_dir/app/Cargo.toml"
make_file "$case_dir/tools/Cargo.toml"

expect_equal "finds only the crate under the current directory" \
  "$(crates_from "$case_dir/tools")" "Cargo.toml"

begin_case outside-a-repo-only-the-crate-in-place-is-found
make_file "$case_dir/Cargo.toml"
make_file "$case_dir/tools/Cargo.toml"

expect_equal "finds the crate at the current directory alone" \
  "$(crates_from "$case_dir")" "Cargo.toml"

begin_case outside-a-repo-no-crate-finds-nothing
expect_equal "finds nothing" "$(crates_from "$case_dir")" ""

exit_with_summary
