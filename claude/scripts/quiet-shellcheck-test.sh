#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests quiet-shellcheck.sh: which of the shell files it lints, and that its
# exit status separates a finding from shellcheck being unable to run.
# `shellcheck-lint.sh` halts the turn on either, but a caller reading the levels
# apart sees breakage rather than something to fix.
#
# Which files count as shell is `find_shell_files`'s to decide, and
# file-listing-test.sh covers it.
#
# Runs the real shellcheck, shfmt and git against a temporary tree. No network
# calls, so it is safe to run anywhere.

script_dir=$(cd "$(dirname "$0")" && pwd)
quiet_shellcheck="$script_dir/quiet-shellcheck.sh"

source "$script_dir/shell-test-framework.sh"

require_commands shellcheck shfmt git

# --- helpers ----------------------------------------------------------------

# Runs the runner from inside the case's repo, the way the lint step does,
# leaving both streams in `$output` and the exit status in `$exit_code`.
run_runner() { # run_runner [runner arguments...]
  output=$(cd "$case_dir" && "$quiet_shellcheck" "$@" 2>&1)
  exit_code=$?
}

# --- cases ------------------------------------------------------------------

begin_case reports-a-finding
git -C "$case_dir" init --quiet
# An unguarded cd is SC2164, which shellcheck reports on any bash file.
printf '#!/usr/bin/env bash\ncd /tmp\n' > "$case_dir/unguarded.sh"
run_runner

expect "exits 1, the findings level" test "$exit_code" -eq 1
expect "names the file" contains "$output" "unguarded.sh"
expect "names the finding" contains "$output" "SC2164"

begin_case reports-a-clean-tree
git -C "$case_dir" init --quiet
printf '#!/usr/bin/env bash\ncd /tmp || exit 1\n' > "$case_dir/guarded.sh"
run_runner

expect "exits 0" test "$exit_code" -eq 0
expect "summarizes rather than listing files" contains "$output" "1 linted"

# `shellcheck` rejects zsh outright, so linting one would report the rejection
# as a finding and halt every turn. quiet-shfmt.sh still formats them.
begin_case leaves-zsh-files-unlinted
git -C "$case_dir" init --quiet
printf 'cd /tmp\n' > "$case_dir/.settings.zsh"
printf 'cd /tmp\n' > "$case_dir/.zshrc"
run_runner

expect "exits 0" test "$exit_code" -eq 0
expect "says it found nothing to lint" contains "$output" "no shell files"

begin_case reports-a-tree-with-no-shell
git -C "$case_dir" init --quiet
printf 'notes, not shell\n' > "$case_dir/README.md"
run_runner

expect "exits 0" test "$exit_code" -eq 0
expect "says there is nothing to do" contains "$output" "no shell files"

begin_case reports-a-missing-named-file
git -C "$case_dir" init --quiet
run_runner absent.sh

expect "exits above the findings level" test "$exit_code" -gt 1
expect "names the missing file" contains "$output" "absent.sh"

# --- summary ----------------------------------------------------------------

exit_with_summary
