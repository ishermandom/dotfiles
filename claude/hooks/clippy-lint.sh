#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: report clippy's findings on every Rust crate in the
# repo the session is working in. Stays silent while the code is clean, and
# where there is no crate at all; on findings it prints them and exits non-zero,
# which `stop_checks.sh` turns into the message that halts the turn.

# This hook's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
hooks_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "$hooks_dir/../scripts/homebrew-path.sh"
source "$hooks_dir/../scripts/file-listing.sh"

# The hook inherits the session's current directory, which may sit below the
# repo root, where a crate elsewhere in the repo would go unchecked. Anchor on
# the root; outside a repo, check in place.
repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
cd "${repo_root:-$PWD}" || exit 1

# `${#crate_manifests[@]}` counts the crates found; with none, there is nothing
# to check.
find_crate_manifests
[ ${#crate_manifests[@]} -gt 0 ] || exit 0

if ! command -v cargo > /dev/null; then
  echo "clippy-lint.sh: cargo not found; install it with 'brew install rust'"
  exit 1
fi

# --all-targets extends the lints to the tests, and --deny warnings makes any
# finding fail the step. --color never because the findings reach the user
# inside a JSON string that renders as plain text: cargo leaves color off in a
# pipe by default, but a CARGO_TERM_COLOR or CLICOLOR_FORCE in the environment
# would turn it on.
lint_status=0
findings=""
for manifest in "${crate_manifests[@]}"; do
  output=$(cargo clippy --quiet --all-targets --color never \
    --manifest-path "$manifest" -- --deny warnings 2>&1)
  clippy_status=$?
  if [ $clippy_status -ne 0 ]; then
    findings+="$output"$'\n'
    lint_status=1
  fi
done

[ $lint_status -eq 0 ] && exit 0
printf '%s' "$findings"
exit 1
