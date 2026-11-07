#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean `shellcheck` runner: lint the given shell files (default: every
# shell file under the current directory that git does not ignore), printing one
# summary line when clean and the findings otherwise. Canonical `shellcheck`
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

# Lint only what `shellcheck` understands: it covers sh, bash, dash, and ksh,
# and rejects zsh outright. The zsh startup files carry no shebang for it to key
# on, so they would come back as an unknown shell. `quiet-shfmt.sh` still
# formats them.
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
#
# `shellcheck` checks one file after another on a single core, so the files are
# split into up to four batches of consecutive files, checked at once: over the
# dotfiles repo's 48 files, 1.38s becomes 0.44s (measured 2026-11-07). Each file
# is still checked once and on its own — the runner passes no `-x`, so
# `shellcheck` never follows `source` into another file — so the split cannot
# change a finding. Four batches leave room for the checks the Stop hook runs
# alongside this one.
#
# The trailing `&` runs a batch in the background, `$!` is its process ID, and
# `${lint_files[@]:start:batch_size}` is the slice of the array that the batch
# checks.
batch_size=$(((${#lint_files[@]} + 3) / 4))
batch_outputs=()
batch_pids=()
for ((start = 0; start < ${#lint_files[@]}; start += batch_size)); do
  batch_outputs+=("$(mktemp)")
  shellcheck -f gcc "${lint_files[@]:start:batch_size}" \
    > "${batch_outputs[-1]}" 2>&1 &
  batch_pids+=($!)
done

# The highest exit among the batches is the runner's, so a file `shellcheck`
# could not read outranks a finding elsewhere, as it would in a single run.
# Reading the reports in batch order keeps the findings in file order.
status=0
for batch_pid in "${batch_pids[@]}"; do
  wait "$batch_pid"
  batch_status=$?
  [ $batch_status -gt $status ] && status=$batch_status
done
output=$(cat "${batch_outputs[@]}")
rm -f "${batch_outputs[@]}"

if [ $status -eq 0 ]; then
  echo "shellcheck: ${#lint_files[@]} linted, clean"
  exit 0
fi

# The tool grades its exits the way callers read them — 1 for findings, 2 for a
# file it could not read, and the shell's 127 when it is absent — so the status
# passes straight through. `claude/hooks/format.sh` describes the levels.
printf '%s\n' "$output"
exit $status
