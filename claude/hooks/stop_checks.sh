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

# The checks below skip someone else's checkout. Formatting cannot change that
# verdict, so the check that reaches it runs while formatting does, and its
# answer is read once formatting ends. The trailing `&` runs the check in the
# background, and `$!` is its process ID.
#
# The check answers through its exit status alone, so its stdout holds nothing
# worth keeping and goes to /dev/null. Left alone, it would share this script's
# stdout, which must carry nothing but the JSON verdict Claude Code parses.
"$hooks_dir/is-third-party-repo.sh" "$PWD" > /dev/null &
third_party_pid=$!

# Formatting runs first so each check below reads a file's final text.
#
# `2>&1 > /dev/null` keeps the step's stderr and drops its stdout, which holds
# nothing this hook needs: progress lines such as `prettier: ok`, and the lint
# findings ruff could not fix, which `ruff-lint.sh` below reports anyway.
#
# A non-zero exit means the step could not do its job: either the step script
# itself would not run — missing, or not executable — or a tool it drives could
# not. Both halt the turn, with the reason the step printed on stderr, rather
# than passing silently.
breakage=$("$hooks_dir/format.sh" 2>&1 > /dev/null)
format_status=$?
[ $format_status -eq 0 ] \
  || halt_turn "${breakage:-format.sh exited $format_status without output}"

# The checks below grade a repo against this machine's global ruff and mypy
# configuration, which a checkout of someone else's project never agreed to. The
# findings there are not the session's to fix, and they would halt every turn.
# Formatting above reaches the same verdict for itself, skipping the session's
# own repo while still sweeping the dotfiles checkout. `wait` returns the
# check's own exit status, 0 for someone else's checkout.
wait "$third_party_pid" && exit 0

# The checks only read the files formatting has settled, so they run in
# parallel, each into a file of its own. Once all finish, their verdicts are
# read in the order below, and the first failure halts the turn with that
# check's report alone.
#
# One report keeps a single cause from showing up several times over: a syntax
# error fails mypy, every test that imports the file, and lint alike. Failures
# that merely coincide, such as a broken test beside an unrelated lint finding,
# look the same from here, and telling them apart would mean parsing every
# tool's output. So every report after the first is held back, at the cost of
# one more round of fixes: every check runs again at the next Stop, and a
# held-back finding shows then.
#
# The order puts first what tends to explain the rest — a type error usually
# explains the test failures that follow it — and lint last, since its findings
# explain nothing above them.
#
# Both streams are captured, so a step is free to report on either: stderr is
# the natural stream for a diagnostic, and a check that used it would otherwise
# halt the turn with nothing but its exit status.
#
# prewarm_checks.sh runs this same list; a check added here belongs there too.
checks=(mypy-check.sh run_tests.sh ruff-lint.sh)
check_outputs=()
check_pids=()
for check in "${checks[@]}"; do
  # `[-1]` is an array's last element: the file just made for this check.
  check_outputs+=("$(mktemp)")
  "$hooks_dir/$check" > "${check_outputs[-1]}" 2>&1 &
  check_pids+=($!)
done

# `${!checks[@]}` lists the array's indices, which pair each check with its
# process ID and its output file.
check_statuses=()
for index in "${!checks[@]}"; do
  wait "${check_pids[$index]}"
  check_statuses+=($?)
done

for index in "${!checks[@]}"; do
  check_status=${check_statuses[$index]}
  [ "$check_status" -eq 0 ] && continue

  failure=$(cat "${check_outputs[$index]}")
  rm -f "${check_outputs[@]}"
  halt_turn "${failure:-${checks[$index]} exited $check_status without output}"
done
rm -f "${check_outputs[@]}"
