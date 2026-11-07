#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: report shellcheck's findings on the shell files in
# the repo the session is working in. Stays silent while the shell is clean; on
# findings it prints them and exits non-zero, which `stop_checks.sh` turns into
# the message that halts the turn.
#
# `format.sh` runs shfmt ahead of this step, so the findings are read from each
# file's final text. Formatting sweeps the dotfiles checkout alongside the
# session's repo, but this step covers the session's repo alone, because a stale
# finding in dotfiles would otherwise halt every turn in every project on the
# machine.

# This hook's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
hooks_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# The hook inherits the session's current directory, which may sit below the
# repo root, where a finding elsewhere in the repo would go unreported. Anchor
# on the root; outside a repo, lint in place.
repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
cd "${repo_root:-$PWD}" || exit 1

lint_output=$("$hooks_dir/../scripts/quiet-shellcheck.sh" 2>&1)
lint_status=$?

# The runner grades its exits — 1 for findings, 2 or more when shellcheck could
# not run at all — but both halt the turn with whatever it said, so the level
# goes unread here.
[ $lint_status -eq 0 ] && exit 0

printf '%s\n' "$lint_output"
exit 1
