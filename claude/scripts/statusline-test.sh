#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for statusline.sh, at the two levels the script is built in.
#
# The colors and the countdown are pure functions of their arguments, so those
# cases source the script and call them directly — no input object, no jq, no
# subprocess, and the instant to measure from passed in rather than stubbed.
#
# Reading the input, asking git and assembling the line only happen when the
# script runs, so the cases about those feed it an input object on stdin and
# assert on the line it prints. Those runs read the wall clock, which a stubbed
# `date` first on PATH freezes.
#
# Runs offline against a temporary tree, so it is safe to run anywhere. Requires
# jq, which statusline.sh uses to read its input.

script_dir=$(cd "$(dirname "$0")" && pwd)
statusline="$script_dir/statusline.sh"

source "$script_dir/shell-test-framework.sh"

require_commands jq

# Sourcing defines the functions and stops at the guard, so nothing runs. The
# path is spelled out rather than reusing `$statusline` above, matching how the
# framework is sourced — shellcheck follows a source it can resolve, and reads
# neither through a second variable.
source "$script_dir/statusline.sh"

# --- frozen clock -----------------------------------------------------------

# An arbitrary instant; only the offsets the cases add to it carry meaning. The
# unit cases pass it as an argument, and the runs below reach it through the
# stub, so both halves measure from the same place.
export FROZEN_NOW=1800000000

# Quoted delimiter: $FROZEN_NOW must reach the stub unexpanded and resolve when
# the stub runs.
mkdir -p "$test_script_root/bin"
cat > "$test_script_root/bin/date" << 'STUB'
#!/bin/sh
# Stubbed date: statusline.sh asks only for epoch seconds, so any other
# request means the script grew a call this stub has to answer.
if [ "$1" != "+%s" ]; then
  echo "date stub: expected '+%s', got '$*'" >&2
  exit 1
fi
echo "$FROZEN_NOW"
STUB
chmod +x "$test_script_root/bin/date"
PATH="$test_script_root/bin:$PATH"

# --- fixtures ---------------------------------------------------------------

# A plain directory for the cases that are not about git state.
mkdir "$test_script_root/workspace"

# Git discovery walks upward, so without a ceiling a repository anywhere above
# the temporary tree would add a segment to every expected line.
export GIT_CEILING_DIRECTORIES="$test_script_root"

# A repository with one commit, then one line rewritten and one appended in the
# working tree.
repository="$test_script_root/repository"
mkdir "$repository"
git -C "$repository" init -q -b statusline-fixture
printf 'first\nsecond\nthird\n' > "$repository/notes.txt"
git -C "$repository" add notes.txt
# An identity on the command line, so the machine's git config cannot decide
# whether this commit succeeds.
git -C "$repository" -c user.name="Statusline Test" \
  -c user.email="statusline-test@example.com" -c commit.gpgsign=false \
  commit -q -m "Add notes"
printf 'first\nSECOND\nthird\nfourth\n' > "$repository/notes.txt"

# --- expected colors --------------------------------------------------------

# The codes statusline.sh emits, spelled out here rather than read from the
# script, so a case asserts against a value of its own. Lower case, since the
# script's own names are in scope after the sourcing above and reassigning them
# would change what the functions emit.
green=$'\033[38;2;51;189;38m'
yellow=$'\033[38;2;174;173;37m'
red=$'\033[38;2;195;56;32m'
gray=$'\033[38;5;245m'
reset=$'\033[0m'

# --- helpers ----------------------------------------------------------------

# The reset instant a case means, from seconds remaining in the window.
resets_in() { # resets_in <seconds from now>
  echo $((FROZEN_NOW + $1))
}

# Builds the input object from the fields a case names, runs the script on that
# object, and leaves the printed line in `output`. A field left unnamed is
# absent from the JSON — the shape the script sees when a quota or a percentage
# is missing. Reset times are given as seconds from now and written out as
# absolute epochs, the form the real input carries.
run_statusline() { # run_statusline [--model M] [--context P] ...
  # A jq program of assignments applied left to right. The defaults come first,
  # so a field a case names overrides its default.
  local program='.model.display_name = "Opus 5"'
  program+=" | .workspace.current_dir = \"$test_script_root/workspace\""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) program+=" | .model.display_name = \"$2\"" ;;
      --effort) program+=" | .effort.level = \"$2\"" ;;
      --dir) program+=" | .workspace.current_dir = \"$2\"" ;;
      --context) program+=" | .context_window.used_percentage = $2" ;;
      --five-hour) program+=" | .rate_limits.five_hour.used_percentage = $2" ;;
      --five-hour-resets-in)
        program+=" | .rate_limits.five_hour.resets_at = $(resets_in "$2")"
        ;;
      --seven-day) program+=" | .rate_limits.seven_day.used_percentage = $2" ;;
      --seven-day-resets-in)
        program+=" | .rate_limits.seven_day.resets_at = $(resets_in "$2")"
        ;;
      *)
        # Ends the run rather than the call: returning would leave `output`
        # holding the previous case's line for the assertion to pass on.
        echo "run_statusline: unknown field '$1'" >&2
        exit 1
        ;;
    esac
    # Every field takes a value, so each arm consumes two arguments.
    shift 2
  done

  # Built separately from the run, so a jq error surfaces on its own rather than
  # reaching the script as empty input.
  local input_object
  input_object=$(jq -n "$program") || exit 1
  output=$(printf '%s' "$input_object" | "$statusline")
}

# --- the coloring and countdown functions -----------------------------------

# Context coloring is absolute: green below 50%, yellow below 80%, red at or
# above 80%.
begin_case context-coloring
expect_equal "colors 49% green" "$(context_color 49)" "$green"
expect_equal "colors 50% yellow" "$(context_color 50)" "$yellow"
expect_equal "colors 79% yellow" "$(context_color 79)" "$yellow"
expect_equal "colors 80% red" "$(context_color 80)" "$red"

# Pace coloring measures usage against how far into the window we are, not
# against a fixed threshold. Half the 5h window has elapsed here, so 50% used is
# exactly on pace.
begin_case quota-pace-coloring
half_gone=$(resets_in $((2 * 3600 + 30 * 60)))
expect_equal "colors on-pace usage green" \
  "$(quota_color 50 "$half_gone" 18000 "$FROZEN_NOW")" "$green"
expect_equal "colors a point over pace yellow" \
  "$(quota_color 51 "$half_gone" 18000 "$FROZEN_NOW")" "$yellow"
expect_equal "colors 15 points over pace yellow" \
  "$(quota_color 65 "$half_gone" 18000 "$FROZEN_NOW")" "$yellow"
expect_equal "colors 16 points over pace red" \
  "$(quota_color 66 "$half_gone" 18000 "$FROZEN_NOW")" "$red"
# 90% of the window has gone by, which leaves 85% used under pace.
expect_equal "keeps a high number green while it stays under pace" \
  "$(quota_color 85 "$(resets_in $((30 * 60)))" 18000 "$FROZEN_NOW")" "$green"

# A window that has only just opened counts as 1% elapsed rather than 0%, so the
# first percent used still reads as on pace.
begin_case quota-pace-at-window-start
just_opened=$(resets_in $((5 * 3600)))
expect_equal "colors the first percent green" \
  "$(quota_color 1 "$just_opened" 18000 "$FROZEN_NOW")" "$green"
expect_equal "colors 20% at the window start red" \
  "$(quota_color 20 "$just_opened" 18000 "$FROZEN_NOW")" "$red"

# With no reset time there is no window to pace against, so the quota falls back
# to fixed thresholds: green below 70%, yellow below 90%, red at or above 90%.
begin_case quota-thresholds-without-a-reset-time
expect_equal "colors 69% green" \
  "$(quota_color 69 -1 18000 "$FROZEN_NOW")" "$green"
expect_equal "colors 70% yellow" \
  "$(quota_color 70 -1 18000 "$FROZEN_NOW")" "$yellow"
expect_equal "colors 89% yellow" \
  "$(quota_color 89 -1 18000 "$FROZEN_NOW")" "$yellow"
expect_equal "colors 90% red" \
  "$(quota_color 90 -1 18000 "$FROZEN_NOW")" "$red"

# The countdown shows the two coarsest units in play, and stops once the window
# it counts down to has arrived.
begin_case reset-countdown
expect_equal "counts days and hours" \
  "$(reset_suffix "$(resets_in $((2 * 86400 + 5 * 3600)))" "$FROZEN_NOW")" \
  " ${gray}(2d 5h)${reset}"
expect_equal "counts hours and minutes" \
  "$(reset_suffix "$(resets_in $((3 * 3600 + 50 * 60)))" "$FROZEN_NOW")" \
  " ${gray}(3h 50m)${reset}"
expect_equal "counts minutes alone" \
  "$(reset_suffix "$(resets_in $((45 * 60)))" "$FROZEN_NOW")" \
  " ${gray}(45m)${reset}"
expect_equal "shows nothing at the reset instant" \
  "$(reset_suffix "$FROZEN_NOW" "$FROZEN_NOW")" ""

# git's summary names only the sides that changed, in the singular for one line,
# and is empty when nothing did.
begin_case shortstat-counts
expect_equal "reads both sides" \
  "$(shortstat_counts ' 16 files changed, 481 insertions(+), 161 deletions(-)')" \
  "481 161"
expect_equal "reads a single line on each side" \
  "$(shortstat_counts ' 1 file changed, 1 insertion(+), 1 deletion(-)')" "1 1"
expect_equal "counts an absent deletions side as zero" \
  "$(shortstat_counts ' 1 file changed, 2 insertions(+)')" "2 0"
expect_equal "counts an absent insertions side as zero" \
  "$(shortstat_counts ' 1 file changed, 3 deletions(-)')" "0 3"
expect_equal "counts an empty summary as no changes" \
  "$(shortstat_counts '')" "0 0"

# --- the line the script assembles ------------------------------------------

# Every segment at once, in the order the line assembles them.
begin_case assembles-the-whole-line
run_statusline --model "Opus 5" --effort high \
  --dir "$test_script_root/workspace" --context 42 \
  --five-hour 20 --five-hour-resets-in "$((3 * 3600 + 50 * 60))" \
  --seven-day 55 --seven-day-resets-in "$((2 * 86400 + 5 * 3600))"
expected="[Opus 5 · high] workspace"
expected+=" | ctx ${green}42%${reset}"
expected+=" | 5h ${green}20%${reset} ${gray}(3h 50m)${reset}"
expected+=" | 7d ${green}55%${reset} ${gray}(2d 5h)${reset}"
expect "prints the model, directory, context and both quotas" \
  [ "$output" = "$expected" ]

# The effort suffix appears only when the input carries an effort level.
begin_case model-label
run_statusline --model "Opus 5" --effort high
expect "joins the model and the effort" contains "$output" "[Opus 5 · high]"
run_statusline --model "Opus 5"
expect "drops the separator when effort is absent" \
  contains "$output" "[Opus 5]"

# used_percentage is null right after /compact and missing before the first
# response; either way there is no number to show.
begin_case absent-context
run_statusline --context null
expect "shows a dash for a null percentage" contains "$output" "| ctx –"
run_statusline
expect "shows a dash when the field is missing" contains "$output" "| ctx –"

# rate_limits is missing on API-key accounts, and a quota with no number has no
# segment to print.
begin_case absent-quotas
run_statusline --context 42
expect "omits the 5h segment" not_contains "$output" "5h"
expect "omits the 7d segment" not_contains "$output" "7d"

# Nothing else pins the window length each quota is paced against, which the
# script supplies at the call site rather than the function deciding: half a
# week gone with half the quota used is on pace.
begin_case window-lengths
run_statusline --seven-day 50 \
  --seven-day-resets-in "$((3 * 86400 + 12 * 3600))"
expect "paces the 7d quota over a week" contains "$output" "7d ${green}50%"
run_statusline --seven-day 51 \
  --seven-day-resets-in "$((3 * 86400 + 12 * 3600))"
expect "so a point over reads as over pace" contains "$output" "7d ${yellow}51%"

# Git state goes last, after the quotas, so the segments ahead of it hold their
# position as edits come and go.
begin_case git-state
run_statusline --model "Opus 5" --dir "$repository" --context 42 --five-hour 10
expected="[Opus 5] repository | ctx ${green}42%${reset}"
expected+=" | 5h ${green}10%${reset}"
# The fixture rewrote one line and appended another, and a rewrite counts as a
# deletion plus an addition.
expected+=" | ⎇ statusline-fixture ${green}+2${reset} ${red}-1${reset}"
expect "ends with the branch and its line counts" \
  [ "$output" = "$expected" ]

# --- summary ----------------------------------------------------------------

exit_with_summary
