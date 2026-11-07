#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: report clippy's findings on every Rust crate in the
# repo the session is working in. Stays silent while the code is clean, and
# where there is no crate at all; on findings it prints them and exits non-zero,
# which `stop_checks.sh` turns into the message that halts the turn.
#
# The clippy invocation is the quiet-clippy runner's, so its flags live in one
# place (~/.claude/scripts/quiet-clippy.sh).

# This hook's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
hooks_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# The hook inherits the session's current directory, which may sit below the
# repo root, where a crate elsewhere in the repo would go unchecked. Anchor on
# the root; outside a repo, check in place.
repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
cd "${repo_root:-$PWD}" || exit 1

lint_output=$("$hooks_dir/../scripts/quiet-clippy.sh" 2>&1)
lint_status=$?

# The runner's summary line on a clean run is for a run by hand; the step stays
# silent. Any failure halts the turn with whatever the runner said.
[ $lint_status -eq 0 ] && exit 0

printf '%s\n' "$lint_output"
exit 1
