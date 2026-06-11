#!/bin/bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Status line for Claude Code: model + effort, directory, git branch and line
# changes, context-window usage, and 5h/7d quota usage colored by burn pace.

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

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
# Countdown color. ANSI dim vanishes on translucent terminal backgrounds; this
# 256-color gray renders at full strength there — close to the default
# foreground, which is fine: legibility beats differentiation.
GRAY=$'\033[38;5;245m'
RESET=$'\033[0m'

# Context coloring: green below 50%, yellow below 80%, red at or above 80%.
context_color() {
  if [ "$1" -lt 50 ]; then
    printf '%s' "$GREEN"
  elif [ "$1" -lt 80 ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$RED"
  fi
}

# Quota coloring by burn pace: compare usage against how far into the window
# we are. Green at or under pace, yellow up to 15 points over, red beyond.
# Falls back to absolute 70/90 thresholds when resets_at is absent.
quota_color() {
  local used="$1" resets_at="$2" window_seconds="$3"
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

  local now elapsed_percentage
  now=$(date +%s)
  elapsed_percentage=$(((window_seconds - (resets_at - now)) * 100 / window_seconds))
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

# Gray " (3h 50m)" until the window resets — the context behind the pace
# color.
reset_suffix() {
  local resets_at="$1" now seconds days hours minutes
  [ "$resets_at" -le 0 ] && return
  now=$(date +%s)
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

model_label="$model"
[ "$effort" != "-" ] && model_label="$model · $effort"

# Line counts vs HEAD (staged + unstaged). A modified line counts as one
# deletion plus one addition, so +/- covers added, modified, and deleted.
branch=""
line_changes=""
if git -C "$directory" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$directory" branch --show-current 2> /dev/null)
  read -r added_lines deleted_lines <<< "$(
    git -C "$directory" diff HEAD --numstat 2> /dev/null \
      | awk '{added += $1; deleted += $2} END {printf "%d %d", added, deleted}'
  )"
  [ "$added_lines" -gt 0 ] && line_changes+=" ${GREEN}+${added_lines}${RESET}"
  [ "$deleted_lines" -gt 0 ] && line_changes+=" ${RED}-${deleted_lines}${RESET}"
fi

line="[$model_label] ${directory##*/}"

# used_percentage is null early in the session and right after /compact.
if [ "$context_percentage" -ge 0 ]; then
  line+=" | ctx $(context_color "$context_percentage")${context_percentage}%${RESET}"
else
  line+=" | ctx –"
fi

# rate_limits is absent on API-key accounts and before the first response.
if [ "$five_hour_percentage" -ge 0 ]; then
  line+=" | 5h $(quota_color "$five_hour_percentage" "$five_hour_resets_at" 18000)"
  line+="${five_hour_percentage}%${RESET}$(reset_suffix "$five_hour_resets_at")"
fi
if [ "$seven_day_percentage" -ge 0 ]; then
  line+=" | 7d $(quota_color "$seven_day_percentage" "$seven_day_resets_at" 604800)"
  line+="${seven_day_percentage}%${RESET}$(reset_suffix "$seven_day_resets_at")"
fi

# Git state goes last: its width changes as edits come and go, and trailing
# position keeps the rest of the line from shifting.
git_state="${branch:+⎇ $branch}${line_changes}"
[ -n "$git_state" ] && line+=" | ${git_state# }"

printf '%s\n' "$line"
