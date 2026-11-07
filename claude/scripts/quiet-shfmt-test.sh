#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests quiet-shfmt.sh: that it rewrites the files it finds or is handed, and
# that it reports a file it cannot parse at the breakage level rather than as a
# finding. The second half is the one that fails quietly if it regresses —
# `format.sh` reads an exit of 1 as "ran, and found something", so an
# unparseable script graded there would pass for a clean run.
#
# Which files count as shell is `find_shell_files`'s to decide, and
# file-listing-test.sh covers it, including a missing shfmt. That case is out of
# reach here: the runner adds Homebrew's bin to PATH, so shfmt cannot be taken
# away.
#
# Runs the real shfmt and git against a temporary tree. No network calls, so it
# is safe to run anywhere.

script_dir=$(cd "$(dirname "$0")" && pwd)
quiet_shfmt="$script_dir/quiet-shfmt.sh"

source "$script_dir/shell-test-framework.sh"

require_commands shfmt git

# --- helpers ----------------------------------------------------------------

# Writes a shell file indented four spaces, which shfmt rewrites to two, under a
# first line of <first line>.
write_misformatted() { # write_misformatted <path> <first line>
  printf '%s\nif true; then\n    echo hello\nfi\n' "$2" > "$1"
}

# Prints `true` when shfmt rewrote the file's four-space indentation to its own
# two, and `false` when the original survived.
was_reformatted() { # was_reformatted <path>
  if grep -q '^    echo hello' "$1"; then echo false; else echo true; fi
}

# Runs the runner from inside the case's repo, the way the formatting step does,
# leaving both streams in `$output` and the exit status in `$exit_code`.
run_runner() { # run_runner [runner arguments...]
  output=$(cd "$case_dir" && "$quiet_shfmt" "$@" 2>&1)
  exit_code=$?
}

# --- cases ------------------------------------------------------------------

begin_case formats-what-it-finds
git -C "$case_dir" init --quiet
write_misformatted "$case_dir/script.sh" '#!/usr/bin/env bash'
write_misformatted "$case_dir/.zshrc" '# zsh startup'
run_runner

expect "exits 0" test "$exit_code" -eq 0
expect_equal "reindents a bash file" \
  "$(was_reformatted "$case_dir/script.sh")" true
expect_equal "and a zsh one" "$(was_reformatted "$case_dir/.zshrc")" true
expect "summarizes rather than listing files" contains "$output" "2 formatted"

begin_case formats-only-a-named-file
git -C "$case_dir" init --quiet
write_misformatted "$case_dir/named.sh" '#!/usr/bin/env bash'
write_misformatted "$case_dir/sibling.sh" '#!/usr/bin/env bash'
run_runner named.sh

expect_equal "formats the named file" \
  "$(was_reformatted "$case_dir/named.sh")" true
expect_equal "and leaves its sibling alone" \
  "$(was_reformatted "$case_dir/sibling.sh")" false

# shfmt grades an unparseable file 1, and the runner raises it, so `format.sh`
# halts the turn instead of passing the file over.
begin_case raises-a-parse-error-to-breakage
git -C "$case_dir" init --quiet
printf '#!/usr/bin/env bash\nif true; then\n    echo hello\n' \
  > "$case_dir/unterminated.sh"
run_runner

expect "exits 2, above the findings level" test "$exit_code" -eq 2
expect "names the file it could not parse" contains "$output" "unterminated.sh"

begin_case reports-a-tree-with-no-shell
git -C "$case_dir" init --quiet
printf 'notes, not shell\n' > "$case_dir/README.md"
run_runner

expect "exits 0" test "$exit_code" -eq 0
expect "says there is nothing to do" contains "$output" "no shell files"

# A named file that is not there fails loudly rather than passing silently.
begin_case reports-a-missing-named-file
git -C "$case_dir" init --quiet
run_runner absent.sh

expect "exits at the breakage level" test "$exit_code" -eq 2
expect "names the missing file" contains "$output" "absent.sh"

# --- summary ----------------------------------------------------------------

exit_with_summary
