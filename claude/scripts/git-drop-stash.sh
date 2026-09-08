#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Drops a stash named by its commit SHA rather than by its `stash@{n}` slot.
#
# `git stash drop` accepts only a slot, and slots renumber whenever any earlier
# entry is pushed or dropped — so a slot read from an earlier command can name a
# different stash by the time the drop runs. Concurrent sessions make that
# ordinary rather than theoretical: `refs/stash` is shared across a repo's
# worktrees, so a background agent stashing in one worktree renumbers every
# other worktree's slots.
#
# A SHA names one stash for as long as that stash exists. This resolves the SHA
# to its current slot, then reads the list back afterwards to confirm the
# intended entry is the one that went. Checking after the drop rather than
# before it is deliberate: no check can close the gap between a lookup and the
# drop that follows, so the only reliable confirmation is the one taken once the
# drop has happened.
#
# To recover a stash dropped by mistake, run `git stash store <sha>` — the
# commit object survives until garbage collection reclaims it, and both this
# script and `git stash drop` print the SHA that was dropped.
#
# Usage: git drop-stash <sha>
#
# The argument is any revision git understands, so `stash@{1}` works too and is
# safer here than passing that slot to `git stash drop`: the slot is pinned to a
# SHA up front, and the drop is confirmed against that SHA afterwards.
#
# Exit codes: 0 = dropped; 1 = no stash holds the SHA, the slots shifted
# mid-run, or the drop failed; 2 = usage error.

# $# is the argument count; the command takes exactly one.
if [ $# -ne 1 ]; then
  echo "usage: git drop-stash <sha>" >&2
  exit 2
fi

# `^{commit}` rejects a revision that names something other than a commit.
# --verify --quiet leaves the output empty instead of printing an error.
requested_revision=$1
target_sha=$(git rev-parse --verify --quiet "$requested_revision^{commit}")
if [ -z "$target_sha" ]; then
  echo "git drop-stash: $requested_revision does not name a commit" >&2
  exit 1
fi

# `git stash list` is `git log` walking the stash reflog, so it takes git's log
# placeholders, one entry per line:
#
# - `%gd` — the reflog selector, shortened for reading: `stash@{0}` rather than
#   `refs/stash@{0}`. This is the slot, and it is exactly what `git stash drop`
#   expects.
# - `%H` — the stash commit's full SHA.
#
# So each line reads `stash@{n} <sha>`. The awk program names both fields rather
# than comparing `$2` and printing `$1`, which would otherwise sit a line below
# a shell `$1` meaning something else entirely. awk exits at the first match, so
# a SHA held at two slots resolves to the earlier one.
find_slot() { # find_slot <wanted_sha>
  local wanted_sha=$1
  git stash list --format='%gd %H' | awk -v wanted="$wanted_sha" '
    { slot = $1; entry_sha = $2 }
    entry_sha == wanted { print slot; exit }
  '
}

# Counting occurrences rather than testing presence keeps the after-check honest
# when two slots hold the same SHA. `%H` is the full SHA, as above.
count_occurrences() { # count_occurrences <sha>
  git stash list --format='%H' | grep --count --line-regexp --fixed-strings "$1"
}

slot=$(find_slot "$target_sha")
if [ -z "$slot" ]; then
  echo "git drop-stash: no stash holds $target_sha" >&2
  exit 1
fi

occurrences_before=$(count_occurrences "$target_sha")

drop_output=$(git stash drop "$slot" 2>&1)
drop_status=$?
if [ $drop_status -ne 0 ]; then
  echo "git drop-stash: dropping $slot failed:" >&2
  echo "$drop_output" >&2
  exit 1
fi

# Read the list back rather than trusting the drop's own message, which is prose
# rather than plumbing.
occurrences_after=$(count_occurrences "$target_sha")
expected_occurrences=$((occurrences_before - 1))
if [ "$occurrences_after" -ne "$expected_occurrences" ]; then
  echo "git drop-stash: the slots shifted and a stash other than $target_sha" \
    "was dropped — git reported:" >&2
  echo "$drop_output" >&2
  echo "restore it with \`git stash store <sha>\` using the SHA above" >&2
  exit 1
fi

echo "git drop-stash: dropped $target_sha from $slot"
