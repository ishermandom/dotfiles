#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Stop hook: run the end-of-turn formatters and checks in a fixed order.
#
# Same-event hooks run in parallel, so registering the steps as separate Stop
# entries would let ruff and prettier rewrite a file while mypy and pytest read
# it. This script is the single Stop entry that orders them; the design record
# covers the choice in claude/docs/design.md #hooks.
#
# Every step is an ordinary script, runnable by hand: a formatter fixes what it
# can and stays quiet, a check prints its failure and exits non-zero. Only this
# script knows how a Stop hook halts a turn, so adding a step takes no knowledge
# of the hook protocol.

# ${BASH_SOURCE[0]} is this script's own path, and -f resolves it through the
# ~/.claude symlink, so the steps are read from the dotfiles repo.
hooks_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Ends the turn and shows the reason to the user; Claude reads the same text
# alongside the user's next message and fixes from there. Callers pass a
# fallback description, since a step can fail without printing anything and an
# empty reason would halt the turn with nothing to act on.
halt_turn() { # halt_turn <text shown to the user>
  # jq -Rs reads all of stdin as a single raw string and encodes it as a JSON
  # string, safely escaping quotes, newlines, etc.
  local json_encoded_reason
  json_encoded_reason=$(printf '%s' "$1" | jq -Rs .)

  printf '{"continue":false,"stopReason":%s}' "$json_encoded_reason"
  exit 0
}

# Formatting runs first so each check below reads a file's final text.
#
# `2>&1 > /dev/null` keeps stderr and drops stdout: this script's stdout carries
# the verdict Claude Code parses, and ruff prints the lint findings it cannot
# fix on its stdout.
#
# A non-zero exit means the step could not do its job: either the step script
# itself would not run — missing, or not executable — or a tool it drives could
# not. Both halt rather than passing silently. A tool's own findings are not a
# failure; the step leaves those on the stdout dropped here, and `ruff-lint.sh`
# below runs the lint pass again to report whatever ruff could not fix.
breakage=$("$hooks_dir/format.sh" 2>&1 > /dev/null)
format_status=$?
[ $format_status -eq 0 ] \
  || halt_turn "${breakage:-format.sh exited $format_status without output}"

# The first check to fail halts the turn and the rest are skipped — a type error
# usually explains the test failures that would follow it. Lint runs last, where
# a finding explains nothing above it and, left unfixed, masks neither a type
# error nor a broken test.
#
# Both streams are captured, so a step is free to report on either: stderr is
# the natural stream for a diagnostic, and a check that used it would otherwise
# halt the turn with nothing but its exit status.
for check in mypy-check.sh run_tests.sh ruff-lint.sh; do
  failure=$("$hooks_dir/$check" 2>&1)
  check_status=$?
  [ $check_status -eq 0 ] && continue

  halt_turn "${failure:-$check exited $check_status without output}"
done
