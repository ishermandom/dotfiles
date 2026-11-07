#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean clippy runner: lint every Rust crate under the current directory,
# printing one summary line when clean and clippy's findings otherwise.
# Canonical clippy invocation — the Stop hook's lint step delegates here.
#
# Exits 0 when every crate came out clean, or when there is none, 1 when clippy
# reported a finding, and 127 when cargo is missing. cargo exits the same way
# for a finding and for a crate that fails to build, so both read as 1.
#
# Usage: quiet-clippy.sh

# $# counts the arguments; the runner takes none.
if [ $# -gt 0 ]; then
  echo "usage: quiet-clippy.sh" >&2
  exit 2
fi

# This script's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
scripts_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "$scripts_dir/homebrew-path.sh"
source "$scripts_dir/file-listing.sh"

# `${#crate_manifests[@]}` counts the crates found; with none, there is nothing
# to lint.
find_crate_manifests
if [ ${#crate_manifests[@]} -eq 0 ]; then
  echo "clippy: no crates"
  exit 0
fi

if ! command -v cargo > /dev/null; then
  echo "clippy: cargo not found; install it with 'brew install rust'"
  exit 127
fi

# cargo leaves color off in a pipe whatever FORCE_COLOR says, so the runner
# honors FORCE_COLOR on cargo's behalf, as ruff does on its own: the Stop hook,
# which inherits the session's FORCE_COLOR, shows clippy's findings in color,
# and a run from Claude's Bash tool, which carries none, stays plain. A
# FORCE_COLOR of 0 asks for no forcing.
case "${FORCE_COLOR:-}" in
  '' | 0) color=auto ;;
  *) color=always ;;
esac

# --all-targets extends the lints to the tests, and --deny warnings turns every
# finding into a failure.
status=0
findings=""
for manifest in "${crate_manifests[@]}"; do
  output=$(cargo clippy --quiet --all-targets --color "$color" \
    --manifest-path "$manifest" -- --deny warnings 2>&1)
  clippy_status=$?
  if [ $clippy_status -ne 0 ]; then
    findings+="$output"$'\n'
    status=1
  fi
done

if [ $status -eq 0 ]; then
  echo "clippy: ${#crate_manifests[@]} linted, clean"
  exit 0
fi
printf '%s' "$findings"
exit 1
