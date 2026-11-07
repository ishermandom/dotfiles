#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean shfmt runner: format the given shell files (default: every shell
# file under the current directory that git does not ignore), printing one
# summary line on success and shfmt's errors otherwise. Canonical shfmt
# invocation — the Stop hook's formatting step delegates here.
#
# Usage: quiet-shfmt.sh [file...]

# This script's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
scripts_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "$scripts_dir/homebrew-path.sh"
source "$scripts_dir/file-listing.sh"

# `$#` is the argument count. A named file is formatted as given; with none,
# `find_shell_files` fills `shell_files`, and its failure has already explained
# itself on stderr.
if [ $# -gt 0 ]; then
  shell_files=("$@")
else
  find_shell_files || exit $?
fi

if [ ${#shell_files[@]} -eq 0 ]; then
  echo "shfmt: no shell files"
  exit 0
fi

# The flags are passed rather than left to an `.editorconfig`, because passing
# any formatting flag makes shfmt ignore `.editorconfig` entirely, and this
# script runs in every project — most of which have no such file to read. `-i 2`
# matches the 2-space indentation these repos use, `-ci` indents case branches,
# `-bn` starts a continuation line with `&&` or `||` rather than ending the
# previous line with it, and `-sr` puts a space after a redirect operator,
# keeping `> /dev/null` and `<<< "$input"` spaced.
output=$(shfmt -i 2 -ci -bn -sr --write "${shell_files[@]}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "shfmt: ${#shell_files[@]} formatted"
  exit 0
fi

# shfmt rewrites whatever it can parse and reports whatever it cannot, with no
# state in between, so every non-zero exit is a file it could not read or parse.
# It grades them all 1, which `format.sh` reads as "ran, and found something it
# could not fix", so the runner raises it to the breakage level. Left at 1, an
# unparseable script would pass for a clean run and go unformatted in silence.
printf '%s\n' "$output"
exit 2
