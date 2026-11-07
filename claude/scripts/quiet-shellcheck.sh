#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean shellcheck runner: lint the given shell files (default: every shell
# file under the current directory that git does not ignore), printing one
# summary line when clean and the findings otherwise. Canonical shellcheck
# invocation — the Stop hook's lint step delegates here.
#
# Usage: quiet-shellcheck.sh [file...]

# This script's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
scripts_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "$scripts_dir/homebrew-path.sh"
source "$scripts_dir/file-listing.sh"

# `$#` is the argument count. A named file is linted as given; with none,
# `find_shell_files` fills `shell_files`, and its failure has already explained
# itself on stderr.
if [ $# -gt 0 ]; then
  shell_files=("$@")
else
  find_shell_files || exit $?
fi

# Lint only what shellcheck understands: it covers sh, bash, dash, and ksh, and
# rejects zsh outright. The zsh startup files carry no shebang for it to key on,
# so they would come back as an unknown shell. `quiet-shfmt.sh` still formats
# them.
lint_files=()
for shell_file in "${shell_files[@]}"; do
  case "$shell_file" in
    *.zsh | *.zshrc | *.zprofile) ;;
    *) lint_files+=("$shell_file") ;;
  esac
done

if [ ${#lint_files[@]} -eq 0 ]; then
  echo "shellcheck: no shell files"
  exit 0
fi

# `-f gcc` prints one line per finding instead of the default excerpt block,
# which keeps a long list of findings readable.
output=$(shellcheck -f gcc "${lint_files[@]}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "shellcheck: ${#lint_files[@]} linted, clean"
  exit 0
fi

# The tool grades its exits the way callers read them — 1 for findings, 2 for a
# file it could not read, and the shell's 127 when it is absent — so the status
# passes straight through. `claude/hooks/format.sh` describes the levels.
printf '%s\n' "$output"
exit $status
