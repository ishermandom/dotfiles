#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests the exit status quiet-ruff.sh reports, and the case where it declines to
# run ruff at all.
#
# The status is the half that fails quietly. claude/hooks/format.sh reads it by
# level — 0 and 1 mean ruff ran, 2 and up mean it could not — so a status that
# flattens those levels turns a broken toolchain into a clean-looking turn.
#
# Two invocations produce that one status, and the cases below cover both how
# they combine and what each level means. A stub ruff on PATH stands in where
# the pairing matters, since real ruff cannot be asked for one status from
# `check` and a different one from `format`.

script_dir=$(cd "$(dirname "$0")" && pwd)
quiet_ruff="$script_dir/quiet-ruff.sh"

. "$script_dir/shell-test-framework.sh"

require_commands ruff

# --- case helpers -----------------------------------------------------------

# Begins a case whose directory is an empty project for ruff to run over. The
# project is a checkout because quiet-ruff.sh anchors its working directory on
# the target's repo root.
begin_project_case() { # begin_project_case <name>
  begin_case "$1"
  git -C "$case_dir" init --quiet
}

# --- cases ------------------------------------------------------------------

begin_project_case skips-a-project-with-no-python
echo "notes" > "$case_dir/notes.txt"
output=$("$quiet_ruff" "$case_dir" 2>&1)
exit_code=$?

expect "a project with no Python files exits clean" test "$exit_code" -eq 0
expect "and says so in its own words" contains "$output" "no Python files"
expect "rather than passing ruff's warning through" \
  not_contains "$output" "No Python files found under"

# The no-Python-files short circuit must not swallow a stale or typo'd path,
# which would be the same silent success the level scale exists to prevent.
begin_project_case reports-a-missing-path
output=$("$quiet_ruff" "$case_dir/gone.py" 2>&1)
exit_code=$?

expect "a path that does not exist is breakage, not a finding" \
  test "$exit_code" -ge 2
expect "and the message names the path rather than its remains" \
  contains "$output" "gone.py"

begin_project_case reports-a-clean-project
printf 'X = 1\n' > "$case_dir/clean.py"
"$quiet_ruff" "$case_dir" > /dev/null 2>&1
exit_code=$?

expect "a clean project exits 0" test "$exit_code" -eq 0

# F821 (undefined name) is reported but has no autofix, so it survives --fix and
# is the status callers must not mistake for a broken tool.
begin_project_case reports-unfixable-findings
printf 'print(undefined_name)\n' > "$case_dir/undefined.py"
output=$("$quiet_ruff" "$case_dir" 2>&1)
exit_code=$?

expect "unfixable findings exit 1" test "$exit_code" -eq 1
expect "and name the rule that fired" contains "$output" "F821"

begin_project_case reports-an-unparseable-file
printf 'def (\n' > "$case_dir/broken.py"
"$quiet_ruff" "$case_dir" > /dev/null 2>&1
exit_code=$?

expect "an unparseable file exits 2 or more" test "$exit_code" -ge 2

# `check` breaking while `format` only reports findings is the pairing that
# tells "worst wins" apart from "the last one wins". Real ruff cannot be made to
# produce it, so a stub stands in. The runner reaches ruff through `uv run`, so
# the stub is a uv that reads the subcommand out of its own arguments — the last
# one, since everything before it configures uv rather than ruff.
begin_project_case takes-the-worse-of-two-statuses
mkdir "$case_dir/stub"
cat > "$case_dir/stub/uv" << 'STUB'
#!/usr/bin/env bash
for argument in "$@"; do
  case "$argument" in
    check) exit 2 ;;
    format) exit 1 ;;
  esac
done
STUB
chmod +x "$case_dir/stub/uv"
printf 'X = 1\n' > "$case_dir/clean.py"
PATH="$case_dir/stub:$PATH" "$quiet_ruff" "$case_dir" > /dev/null 2>&1
exit_code=$?

expect "a breakage in check outranks findings from format" \
  test "$exit_code" -eq 2

# The runner supplies its own ruff through uv, so an empty PATH is no longer a
# missing tool — this is what reaching ruff through the project rather than
# through the environment buys.
begin_project_case runs-with-nothing-on-path
printf 'X = 1\n' > "$case_dir/clean.py"
PATH=/usr/bin:/bin "$quiet_ruff" "$case_dir" > /dev/null 2>&1
exit_code=$?

expect "a bare PATH still runs ruff" test "$exit_code" -eq 0

# --- summary ----------------------------------------------------------------

exit_with_summary
