#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: report the lint findings ruff could not fix on its
# own. Stays silent while the code is clean; on findings it prints them and
# exits non-zero, which `stop_checks.sh` turns into the message that halts the
# turn.
#
# The formatter step runs `ruff check --fix` ahead of this one and drops
# everything it prints, since a formatter's chatter would garble the halt
# verdict. This step is how those findings reach the user — and running after
# the fixes means it reports only what needs a person.

# Hooks and subshells may run with a minimal environment; Homebrew's bin
# directory may not be on PATH, so append it. uv lives there, and the ruff
# invocation below goes through it. Appended rather than prepended, matching
# `quiet-ruff.sh`, so a uv placed earlier on PATH can still be substituted for
# this one.
export PATH="$PATH:/opt/homebrew/bin"

# The hook inherits the session's current directory, which may sit below the
# repo root, where a finding elsewhere in the repo would go unreported. Anchor
# on the root so the check spans the whole repo, and so ruff's import sorting
# can see the top-level package layout it classifies against.
repo_root=$(git rev-parse --show-toplevel 2> /dev/null)

# No --fix: a check reports rather than rewrites, and the format step has
# already applied whatever ruff could fix on its own.
#
# --color never because the findings reach the user inside a JSON string that
# renders as plain text, while the session environment the hook inherits sets
# FORCE_COLOR.
#
# The `:-` runs ruff in place outside a repo, and the cd runs in the command
# substitution's subshell, leaving this script's own directory alone.
run_dir="${repo_root:-$PWD}"

# Reach ruff through uv rather than through PATH, so the version is whatever the
# target repo pins rather than whatever a venv happens to have been activated —
# matching `quiet-ruff.sh`, which the formatter step runs just before this one.
# `--with` supplies a ruff for a repo that declares none, without overriding a
# declared pin.
lint_output=$(cd "$run_dir" \
  && uv run --project "$run_dir" --with ruff ruff check --color never 2>&1)
lint_status=$?

# Ruff grades its own exits — 1 for findings, 2 or more when it could not run —
# but both halt the turn with whatever ruff said, so the level goes unread.
[ $lint_status -eq 0 ] && exit 0

echo "$lint_output"
exit 1
