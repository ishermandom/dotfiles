#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for statusline.sh: feeds it one status-line input object on stdin and
# asserts on the line it prints.
#
# The script reads the wall clock to turn a reset timestamp into a burn pace and
# a countdown, so a stubbed `date` placed first on PATH freezes that clock. Each
# case gives its reset times as offsets from the frozen instant, so both the
# color and the countdown come out exact rather than approximate.
#
# Runs offline against a temporary tree, so it is safe to run anywhere. Requires
# jq, which statusline.sh uses to read its input.

script_dir=$(cd "$(dirname "$0")" && pwd)
statusline="$script_dir/statusline.sh"

if ! command -v jq > /dev/null; then
  echo "statusline-test: jq is missing; try 'brew install jq'" >&2
  exit 1
fi

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# --- frozen clock -----------------------------------------------------------

# An arbitrary instant; only the offsets the cases add to it carry meaning.
export FROZEN_NOW=1800000000

mkdir "$test_root/bin"
# Quoted delimiter: $FROZEN_NOW must reach the stub unexpanded and resolve when
# the stub runs.
cat > "$test_root/bin/date" << 'STUB'
#!/usr/bin/env bash
# Stubbed date: statusline.sh asks only for epoch seconds, so any other
# request means the script grew a call this stub has to answer.
if [ "$1" != "+%s" ]; then
  echo "date stub: expected '+%s', got '$*'" >&2
  exit 1
fi
echo "$FROZEN_NOW"
STUB
chmod +x "$test_root/bin/date"
PATH="$test_root/bin:$PATH"

# --- fixtures ---------------------------------------------------------------

# A plain directory for the cases that are not about git state.
mkdir "$test_root/workspace"

# Git discovery walks upward, so without a ceiling a repository anywhere above
# the temporary tree would add a segment to every expected line.
export GIT_CEILING_DIRECTORIES="$test_root"

# A repository with one commit, then one line rewritten and one appended in the
# working tree.
repository="$test_root/repository"
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

# The codes statusline.sh emits, named so a case can say which color it wants.
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
GRAY=$'\033[38;5;245m'
RESET=$'\033[0m'

# --- helpers ----------------------------------------------------------------

failure_count=0

# Runs the given command as an assertion: prints one result line, and on failure
# bumps failure_count so the script exits non-zero at the end.
expect() { # expect <description> <command...>
  local description="$1"
  shift
  if "$@"; then
    echo "  ok: $description"
  else
    echo "  FAIL: $description" >&2
    failure_count=$((failure_count + 1))
  fi
}

contains() { # contains <haystack> <needle>
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

not_contains() { # not_contains <haystack> <needle>
  ! contains "$1" "$2"
}

begin_case() { # begin_case <name>
  echo "case: $1"
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
  program+=" | .workspace.current_dir = \"$test_root/workspace\""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) program+=" | .model.display_name = \"$2\"" ;;
      --effort) program+=" | .effort.level = \"$2\"" ;;
      --dir) program+=" | .workspace.current_dir = \"$2\"" ;;
      --context) program+=" | .context_window.used_percentage = $2" ;;
      --five-hour) program+=" | .rate_limits.five_hour.used_percentage = $2" ;;
      --five-hour-resets-in)
        program+=" | .rate_limits.five_hour.resets_at = $((FROZEN_NOW + $2))"
        ;;
      --seven-day) program+=" | .rate_limits.seven_day.used_percentage = $2" ;;
      --seven-day-resets-in)
        program+=" | .rate_limits.seven_day.resets_at = $((FROZEN_NOW + $2))"
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

# --- cases ------------------------------------------------------------------

# Every segment at once, in the order the line assembles them.
begin_case assembles-the-whole-line
run_statusline --model "Opus 5" --effort high \
  --dir "$test_root/workspace" --context 42 \
  --five-hour 20 --five-hour-resets-in "$((3 * 3600 + 50 * 60))" \
  --seven-day 55 --seven-day-resets-in "$((2 * 86400 + 5 * 3600))"
expected="[Opus 5 · high] workspace"
expected+=" | ctx ${GREEN}42%${RESET}"
expected+=" | 5h ${GREEN}20%${RESET} ${GRAY}(3h 50m)${RESET}"
expected+=" | 7d ${GREEN}55%${RESET} ${GRAY}(2d 5h)${RESET}"
expect "prints the model, directory, context and both quotas" \
  [ "$output" = "$expected" ]

# The effort suffix appears only when the input carries an effort level.
begin_case model-label
run_statusline --model "Opus 5" --effort high
expect "joins the model and the effort" contains "$output" "[Opus 5 · high]"
run_statusline --model "Opus 5"
expect "drops the separator when effort is absent" \
  contains "$output" "[Opus 5]"

# Context coloring is absolute: green below 50%, yellow below 80%, red at or
# above 80%.
begin_case context-coloring
run_statusline --context 49
expect "colors 49% green" contains "$output" "ctx ${GREEN}49%"
run_statusline --context 50
expect "colors 50% yellow" contains "$output" "ctx ${YELLOW}50%"
run_statusline --context 79
expect "colors 79% yellow" contains "$output" "ctx ${YELLOW}79%"
run_statusline --context 80
expect "colors 80% red" contains "$output" "ctx ${RED}80%"

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

# Pace coloring measures usage against how far into the window we are, not
# against a fixed threshold. Half the 5h window has elapsed in the first four
# runs, so 50% used is exactly on pace.
begin_case quota-pace-coloring
run_statusline --five-hour 50 --five-hour-resets-in "$((2 * 3600 + 30 * 60))"
expect "colors on-pace usage green" contains "$output" "5h ${GREEN}50%"
run_statusline --five-hour 51 --five-hour-resets-in "$((2 * 3600 + 30 * 60))"
expect "colors a point over pace yellow" contains "$output" "5h ${YELLOW}51%"
run_statusline --five-hour 65 --five-hour-resets-in "$((2 * 3600 + 30 * 60))"
expect "colors 15 points over pace yellow" contains "$output" "5h ${YELLOW}65%"
run_statusline --five-hour 66 --five-hour-resets-in "$((2 * 3600 + 30 * 60))"
expect "colors 16 points over pace red" contains "$output" "5h ${RED}66%"
# 90% of the window has gone by, which leaves 85% used under pace.
run_statusline --five-hour 85 --five-hour-resets-in "$((30 * 60))"
expect "keeps a high number green while it stays under pace" \
  contains "$output" "5h ${GREEN}85%"

# A window that has only just opened counts as 1% elapsed rather than 0%, so the
# first percent used still reads as on pace.
begin_case quota-pace-at-window-start
run_statusline --five-hour 1 --five-hour-resets-in "$((5 * 3600))"
expect "colors the first percent green" contains "$output" "5h ${GREEN}1%"
run_statusline --five-hour 20 --five-hour-resets-in "$((5 * 3600))"
expect "colors 20% at the window start red" contains "$output" "5h ${RED}20%"

# The same pace rule against the other window: half a week gone with half the
# quota used is on pace. Nothing else pins the 7d window's length.
begin_case seven-day-window-length
run_statusline --seven-day 50 \
  --seven-day-resets-in "$((3 * 86400 + 12 * 3600))"
expect "colors on-pace usage green" contains "$output" "7d ${GREEN}50%"
run_statusline --seven-day 51 \
  --seven-day-resets-in "$((3 * 86400 + 12 * 3600))"
expect "colors a point over pace yellow" contains "$output" "7d ${YELLOW}51%"

# With no reset time there is no window to pace against, so the quota falls back
# to fixed thresholds: green below 70%, yellow below 90%, red at or above 90%.
begin_case quota-thresholds-without-a-reset-time
run_statusline --five-hour 69
expect "colors 69% green" contains "$output" "5h ${GREEN}69%"
run_statusline --five-hour 70
expect "colors 70% yellow" contains "$output" "5h ${YELLOW}70%"
run_statusline --five-hour 89
expect "colors 89% yellow" contains "$output" "5h ${YELLOW}89%"
run_statusline --five-hour 90
expect "colors 90% red" contains "$output" "5h ${RED}90%"

# The countdown shows the two coarsest units in play, and stops once the window
# it counts down to has arrived.
begin_case reset-countdown
run_statusline --seven-day 10 \
  --seven-day-resets-in "$((2 * 86400 + 5 * 3600))"
expect "counts days and hours" contains "$output" "${GRAY}(2d 5h)${RESET}"
run_statusline --five-hour 10 --five-hour-resets-in "$((3 * 3600 + 50 * 60))"
expect "counts hours and minutes" contains "$output" "${GRAY}(3h 50m)${RESET}"
run_statusline --five-hour 10 --five-hour-resets-in "$((45 * 60))"
expect "counts minutes alone" contains "$output" "${GRAY}(45m)${RESET}"
run_statusline --five-hour 10 --five-hour-resets-in 0
expect "shows no countdown at the reset instant" \
  not_contains "$output" "$GRAY"

# Git state goes last, after the quotas, so the segments ahead of it hold their
# position as edits come and go.
begin_case git-state
run_statusline --model "Opus 5" --dir "$repository" --context 42 --five-hour 10
expected="[Opus 5] repository | ctx ${GREEN}42%${RESET}"
expected+=" | 5h ${GREEN}10%${RESET}"
# The fixture rewrote one line and appended another, and a rewrite counts as a
# deletion plus an addition.
expected+=" | ⎇ statusline-fixture ${GREEN}+2${RESET} ${RED}-1${RESET}"
expect "ends with the branch and its line counts" \
  [ "$output" = "$expected" ]

# --- summary ----------------------------------------------------------------

echo
if [ "$failure_count" -eq 0 ]; then
  echo "statusline tests: all passed"
else
  echo "statusline tests: $failure_count assertion(s) failed" >&2
  exit 1
fi
