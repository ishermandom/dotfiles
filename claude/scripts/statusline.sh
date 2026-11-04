#!/bin/bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Status line for Claude Code: model + effort, directory, git branch and line
# changes, context-window usage, and 5h/7d quota usage colored by burn pace.
#
# The colors and the countdown are decided by the functions below, which take
# everything they need as arguments — the instant to measure from included — so
# they are pure and `statusline-test.sh` can source this file and call them
# directly. Reading the input, asking git, and assembling the line stay under
# the guard near the bottom, which runs only when this file is executed.

# Stated as 24-bit color rather than as ANSI indices, because terminals disagree
# about what the indices mean. Terminal.app draws `\033[31m` from its profile's
# ANSI colors, while Ghostty treats it as entry 1 of its 256-color palette, so
# the same index renders as two different reds. A 24-bit value renders the same
# everywhere that supports it, which includes Terminal.app from macOS 26.
#
# The values are Terminal.app's ANSI green, yellow and red — palette entries 2,
# 3 and 1 in `ghostty/config`, which records where they come from. A change to
# one belongs in both.
GREEN=$'\033[38;2;51;189;38m'
YELLOW=$'\033[38;2;174;173;37m'
RED=$'\033[38;2;195;56;32m'
# Countdown color. ANSI dim vanishes on translucent terminal backgrounds; this
# 256-color gray renders at full strength there — close to the default
# foreground, which is fine: legibility beats differentiation.
GRAY=$'\033[38;5;245m'
RESET=$'\033[0m'

# Context coloring: green below 50%, yellow below 80%, red at or above 80%.
context_color() { # context_color <used percentage>
  if [ "$1" -lt 50 ]; then
    printf '%s' "$GREEN"
  elif [ "$1" -lt 80 ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$RED"
  fi
}

# Quota coloring by burn pace: compare usage against how far into the window we
# are. Green at or under pace, yellow up to 15 points over, red beyond. Falls
# back to absolute 70/90 thresholds when resets_at is absent.
quota_color() { # quota_color <used> <resets at> <window seconds> <now>
  local used="$1" resets_at="$2" window_seconds="$3" now="$4"
  if [ "$resets_at" -le 0 ]; then
    if [ "$used" -lt 70 ]; then
      printf '%s' "$GREEN"
    elif [ "$used" -lt 90 ]; then
      printf '%s' "$YELLOW"
    else
      printf '%s' "$RED"
    fi
    return
  fi

  local elapsed_seconds elapsed_percentage
  elapsed_seconds=$((window_seconds - (resets_at - now)))
  elapsed_percentage=$((elapsed_seconds * 100 / window_seconds))
  [ "$elapsed_percentage" -lt 1 ] && elapsed_percentage=1
  [ "$elapsed_percentage" -gt 100 ] && elapsed_percentage=100

  if [ "$used" -le "$elapsed_percentage" ]; then
    printf '%s' "$GREEN"
  elif [ "$used" -le $((elapsed_percentage + 15)) ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$RED"
  fi
}

# Gray " (3h 50m)" until the window resets — the context behind the pace color.
reset_suffix() { # reset_suffix <resets at> <now>
  local resets_at="$1" now="$2" seconds days hours minutes
  [ "$resets_at" -le 0 ] && return
  seconds=$((resets_at - now))
  [ "$seconds" -le 0 ] && return
  days=$((seconds / 86400))
  hours=$((seconds % 86400 / 3600))
  minutes=$((seconds % 3600 / 60))
  if [ "$days" -gt 0 ]; then
    printf ' %s(%dd %dh)%s' "$GRAY" "$days" "$hours" "$RESET"
  elif [ "$hours" -gt 0 ]; then
    printf ' %s(%dh %dm)%s' "$GRAY" "$hours" "$minutes" "$RESET"
  else
    printf ' %s(%dm)%s' "$GRAY" "$minutes" "$RESET"
  fi
}

# One quota's segment — " | 5h 63% (3h 50m)", colored by pace. Empty when the
# quota is absent: rate_limits is missing on API-key accounts and before the
# first response.
quota_segment() { # quota_segment <label> <used> <resets at> <window> <now>
  local label="$1" used="$2" resets_at="$3" window_seconds="$4" now="$5"
  [ "$used" -lt 0 ] && return
  local color suffix
  color=$(quota_color "$used" "$resets_at" "$window_seconds" "$now")
  suffix=$(reset_suffix "$resets_at" "$now")
  printf '%s' " | $label ${color}${used}%${RESET}${suffix}"
}

# The added and deleted line counts, as "<added> <deleted>", from the summary
# `git diff --shortstat` prints, such as `1 file changed, 2 insertions(+)`: it
# leaves out a side that is zero, and is empty when nothing changed.
# `BASH_REMATCH[1]` is the number the pattern's group matched.
shortstat_counts() { # shortstat_counts <shortstat summary>
  local added=0 deleted=0
  local insertions_pattern='([0-9]+) insertion'
  local deletions_pattern='([0-9]+) deletion'
  [[ $1 =~ $insertions_pattern ]] && added=${BASH_REMATCH[1]}
  [[ $1 =~ $deletions_pattern ]] && deleted=${BASH_REMATCH[1]}
  printf '%s %s' "$added" "$deleted"
}

# Everything below runs only when this file is executed. Sourcing it — which is
# how the tests reach the functions above — stops here.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

input=$(cat)

IFS=$'\t' read -r model effort directory context_percentage \
  five_hour_percentage five_hour_resets_at \
  seven_day_percentage seven_day_resets_at <<< "$(
    jq -r '[.model.display_name,
            (.effort.level // "-"),
            (.workspace.current_dir // "."),
            (.context_window.used_percentage // -1 | floor),
            (.rate_limits.five_hour.used_percentage // -1 | floor),
            (.rate_limits.five_hour.resets_at // -1 | floor),
            (.rate_limits.seven_day.used_percentage // -1 | floor),
            (.rate_limits.seven_day.resets_at // -1 | floor)]
           | @tsv' <<< "$input"
  )"

# Asked once and passed down, so every segment measures against one instant
# rather than each reading a clock that has moved on.
now=$(date +%s)

model_label="$model"
[ "$effort" != "-" ] && model_label="$model · $effort"

# Line counts vs HEAD (staged + unstaged). A modified line counts as one
# deletion plus one addition, so +/- covers added, modified, and deleted.
#
# Two git calls, since this renders on every prompt. `branch --show-current`
# fails only outside a repository, so its status decides whether there is git
# state to show; on a detached head it succeeds with an empty branch.
# `diff HEAD` fails before the first commit, which leaves nothing to count
# rather than dropping the branch.
branch=""
line_changes=""
if branch=$(git -C "$directory" branch --show-current 2> /dev/null); then
  shortstat=$(git -C "$directory" diff HEAD --shortstat 2> /dev/null)
  read -r added_lines deleted_lines <<< "$(shortstat_counts "$shortstat")"
  [ "$added_lines" -gt 0 ] && line_changes+=" ${GREEN}+${added_lines}${RESET}"
  [ "$deleted_lines" -gt 0 ] && line_changes+=" ${RED}-${deleted_lines}${RESET}"
fi

line="[$model_label] ${directory##*/}"

# used_percentage is null early in the session and right after /compact.
if [ "$context_percentage" -ge 0 ]; then
  line+=" | ctx $(context_color "$context_percentage")"
  line+="${context_percentage}%${RESET}"
else
  line+=" | ctx –"
fi

line+=$(quota_segment 5h "$five_hour_percentage" "$five_hour_resets_at" \
  18000 "$now")
line+=$(quota_segment 7d "$seven_day_percentage" "$seven_day_resets_at" \
  604800 "$now")

# Git state goes last: its width changes as edits come and go, and trailing
# position keeps the rest of the line from shifting.
git_state="${branch:+⎇ $branch}${line_changes}"
[ -n "$git_state" ] && line+=" | ${git_state# }"

printf '%s\n' "$line"
