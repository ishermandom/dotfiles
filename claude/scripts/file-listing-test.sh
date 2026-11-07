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
# `find_shell_files` finds shell files by extension or shebang, and by name
# alone for the dot-prefixed files shfmt skips; it leaves out what git ignores,
# a deleted file, and a symlink.
#
# The cases run the real git and shfmt. None needs cargo, since only where a
# manifest sits matters, never what it says.

script_dir=$(cd "$(dirname "$0")" && pwd)

source "$script_dir/shell-test-framework.sh"
source "$script_dir/file-listing.sh"

require_commands git shfmt

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

# Writes a script at <path> whose first line is <first line>, creating its
# directory. shfmt reads the first line to tell an extensionless script's shell.
make_script() { # make_script <path> <first line>
  mkdir -p "$(dirname "$1")"
  printf '%s\necho hello\n' "$2" > "$1"
}

# Lists the shell files found from <directory>, one per line, sorted, since
# their order means nothing either.
shells_from() { # shells_from <directory>
  (cd "$1" && find_shell_files && printf '%s\n' "${shell_files[@]}") | sort
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

# --- find_shell_files -------------------------------------------------------

begin_case shell-is-found-by-extension-and-by-shebang
git -C "$case_dir" init --quiet
make_script "$case_dir/nested/deep.sh" '#!/usr/bin/env bash'
make_script "$case_dir/tool" '#!/usr/bin/env bash'
make_script "$case_dir/report" '#!/usr/bin/env python3'
make_file "$case_dir/notes.md"

expect_equal "finds the .sh and the bash script, and nothing else" \
  "$(shells_from "$case_dir")" "nested/deep.sh
tool"

# shfmt skips every file whose name starts with a dot, so these are found by
# name instead.
begin_case dot-prefixed-shell-is-found-by-name
git -C "$case_dir" init --quiet
make_script "$case_dir/.zshrc" '# zsh startup'
make_script "$case_dir/.helper.sh" '#!/usr/bin/env bash'
make_file "$case_dir/.editorconfig"

expect_equal "finds both, and not the other dot-prefixed file" \
  "$(shells_from "$case_dir")" ".helper.sh
.zshrc"

# The reason to list through git at all: in the dotfiles repo,
# `.claude/worktrees/` is ignored, and the checkouts there hold other sessions'
# work in progress, which a pass from the main checkout must leave alone.
begin_case ignored-shell-is-left-out
git -C "$case_dir" init --quiet
echo "ignored/" > "$case_dir/.gitignore"
make_script "$case_dir/ignored/vendored.sh" '#!/usr/bin/env bash'
make_script "$case_dir/ignored/.dotted.sh" '#!/usr/bin/env bash'
make_script "$case_dir/kept.sh" '#!/usr/bin/env bash'

expect_equal "finds only the file git does not ignore" \
  "$(shells_from "$case_dir")" "kept.sh"

begin_case a-deleted-file-and-a-symlink-are-left-out
git -C "$case_dir" init --quiet
make_script "$case_dir/kept.sh" '#!/usr/bin/env bash'
make_script "$case_dir/gone.sh" '#!/usr/bin/env bash'
ln -s kept.sh "$case_dir/linked.sh"
git -C "$case_dir" add gone.sh linked.sh
rm "$case_dir/gone.sh"

expect_equal "finds only the real file that exists" \
  "$(shells_from "$case_dir")" "kept.sh"

# Outside a repo there are no ignore rules, so every file is considered except
# those inside a `.git` directory. The `.git` here is a bare directory, not a
# repository, so git cannot list from it.
begin_case outside-a-repo-every-file-is-a-candidate
make_script "$case_dir/loose.sh" '#!/usr/bin/env bash'
make_script "$case_dir/.zshrc" '# zsh startup'
make_script "$case_dir/.git/hooks/local.sh" '#!/usr/bin/env bash'

expect_equal "finds both, without find's leading ./, and nothing under .git" \
  "$(shells_from "$case_dir")" ".zshrc
loose.sh"

# Without shfmt, the search could find only the dot-prefixed files, and the rest
# of the repo's shell would go unnoticed. Dropping Homebrew's bin directory,
# where shfmt lives, from PATH removes shfmt while git stays in /usr/bin.
begin_case a-missing-shfmt-fails-the-search
git -C "$case_dir" init --quiet
make_script "$case_dir/.zshrc" '# zsh startup'
output=$(cd "$case_dir" && PATH=/usr/bin:/bin find_shell_files 2>&1 \
  && printf '%s\n' "${shell_files[@]}")
exit_code=$?

expect "fails at the breakage level" test "$exit_code" -eq 2
expect "names the missing tool" contains "$output" "shfmt"
expect "finds nothing" not_contains "$output" ".zshrc"

exit_with_summary
