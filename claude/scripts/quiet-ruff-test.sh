#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests the exit status quiet-ruff.sh reports, and the case where it declines
# to run ruff at all.
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

if ! command -v ruff > /dev/null; then
  echo "quiet-ruff-test: ruff is missing; try 'pip install ruff'" >&2
  exit 1
fi

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

failure_count=0

# --- helpers ----------------------------------------------------------------

# Runs the given command as an assertion: prints one result line, and on
# failure bumps failure_count so the script exits non-zero at the end.
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

lacks() { # lacks <haystack> <needle>
  ! contains "$1" "$2"
}

# Makes an empty project for ruff to run over. It is a checkout because
# quiet-ruff.sh anchors its working directory on the target's repo root.
make_project() { # make_project  -> prints the directory
  local project
  project=$(mktemp -d "$test_root/project.XXXXXX")
  git -C "$project" init --quiet
  echo "$project"
}

# --- a project with no Python files does not reach ruff ---------------------

project=$(make_project)
echo "notes" > "$project/notes.txt"
no_python_output=$("$quiet_ruff" "$project" 2>&1)
no_python_status=$?

expect "a project with no Python files exits clean" \
  test "$no_python_status" -eq 0
expect "and says so in its own words" \
  contains "$no_python_output" "no Python files"
expect "rather than passing ruff's warning through" \
  lacks "$no_python_output" "No Python files found under"

# --- a clean project reports success -----------------------------------------

project=$(make_project)
printf 'X = 1\n' > "$project/clean.py"
"$quiet_ruff" "$project" > /dev/null 2>&1
clean_status=$?

expect "a clean project exits 0" test "$clean_status" -eq 0

# --- findings ruff cannot fix are level 1 ------------------------------------

# F821 (undefined name) is reported but has no autofix, so it survives --fix
# and is the status callers must not mistake for a broken tool.
project=$(make_project)
printf 'print(undefined_name)\n' > "$project/undefined.py"
findings_output=$("$quiet_ruff" "$project" 2>&1)
findings_status=$?

expect "unfixable findings exit 1" test "$findings_status" -eq 1
expect "and name the rule that fired" contains "$findings_output" "F821"

# --- a file ruff cannot parse is breakage, not a finding ---------------------

project=$(make_project)
printf 'def (\n' > "$project/broken.py"
"$quiet_ruff" "$project" > /dev/null 2>&1
unparseable_status=$?

expect "an unparseable file exits 2 or more" test "$unparseable_status" -ge 2

# --- the worse of the two ruff statuses wins ---------------------------------

# `check` breaking while `format` only reports findings is the pairing that
# tells "worst wins" apart from "the last one wins". Real ruff cannot be made
# to produce it, so a stub earlier on PATH stands in.
stub_dir=$(mktemp -d "$test_root/stub.XXXXXX")
cat > "$stub_dir/ruff" << 'STUB'
#!/usr/bin/env bash
case "$1" in
  check) exit 2 ;;
  format) exit 1 ;;
esac
STUB
chmod +x "$stub_dir/ruff"

project=$(make_project)
printf 'X = 1\n' > "$project/clean.py"
PATH="$stub_dir:$PATH" "$quiet_ruff" "$project" > /dev/null 2>&1
worst_status=$?

expect "a breakage in check outranks findings from format" \
  test "$worst_status" -eq 2

# --- a ruff that is not installed is distinguishable from findings -----------

project=$(make_project)
printf 'X = 1\n' > "$project/clean.py"
PATH=/usr/bin:/bin "$quiet_ruff" "$project" > /dev/null 2>&1
missing_status=$?

expect "a missing ruff exits 127" test "$missing_status" -eq 127

# --- summary ----------------------------------------------------------------

if [ "$failure_count" -ne 0 ]; then
  echo "quiet-ruff-test: $failure_count assertion(s) failed" >&2
  exit 1
fi
echo "quiet-ruff-test: all assertions passed"
