#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests which files quiet-prettier.sh formats, which config it formats them
# with, and the exit status it reports.
#
# Discovery and config selection both fail quietly: a file that is never globbed
# is simply not formatted, and the wrong config silently reformats every file it
# does reach. So the cases below assert through an observable effect on a
# fixture file rather than on the summary line.
#
# Runs the real prettier against a temporary tree, with HOME pointed at a
# fixture so the global-config fallback is deterministic rather than whatever
# the machine happens to carry.
#
# One level is out of reach here: the script prepends Homebrew's bin to PATH, so
# prettier cannot be taken away to produce the shell's 127. claude/hooks/
# format-test.sh covers a runner that exits 127 with a fake.

script_dir=$(cd "$(dirname "$0")" && pwd)
quiet_prettier="$script_dir/quiet-prettier.sh"

# quiet-prettier.sh adds Homebrew's bin itself; mirror that here so the guard
# below looks at the same prettier the script will run.
export PATH="/opt/homebrew/bin:$PATH"

if ! command -v prettier > /dev/null; then
  echo "quiet-prettier-test: prettier is missing; brew install prettier" >&2
  exit 1
fi

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

failure_count=0

# --- helpers ----------------------------------------------------------------

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

# Builds a fixture: a project directory to format, plus a fake HOME to resolve
# the script's global-config fallback against. Prints the fixture directory,
# which holds project/ and home/.
#
# The empty global config keeps that fallback pointing at a real file, since
# prettier errors on a --config path that does not exist. The case about the
# fallback overwrites it with a setting it can observe.
make_fixture() { # make_fixture  -> prints the fixture directory
  local fixture
  fixture=$(mktemp -d "$test_root/case.XXXXXX")
  mkdir -p "$fixture/home" "$fixture/project"
  printf '{}\n' > "$fixture/home/.prettierrc"
  echo "$fixture"
}

# Runs the runner inside the fixture's project against its fake HOME, leaving
# both streams in the fixture as stdout. Returns the runner's exit status, which
# is the level claude/hooks/format.sh reads.
run_runner() { # run_runner <fixture> [runner arguments...]
  local fixture="$1"
  shift
  (cd "$fixture/project" && HOME="$fixture/home" "$quiet_prettier" "$@") \
    > "$fixture/stdout" 2>&1
}

# --- a project with nothing to format does not reach prettier ---------------

fixture=$(make_fixture)
echo "notes" > "$fixture/project/notes.txt"
run_runner "$fixture"
no_files_status=$?

expect "a project with nothing to format exits clean" \
  test "$no_files_status" -eq 0
expect "and says so in its own words" \
  contains "$(cat "$fixture/stdout")" "no formattable files"

# --- discovery reaches nested files -----------------------------------------

fixture=$(make_fixture)
mkdir -p "$fixture/project/nested"
printf '#   Title\n' > "$fixture/project/nested/doc.md"
run_runner "$fixture"

expect "a markdown file in a subdirectory is reformatted" \
  test "$(head -1 "$fixture/project/nested/doc.md")" = "# Title"

# --- an extension with no files present is left out of the globs ------------

# Prettier errors on a glob that matches nothing, so a project carrying only
# markdown must not be handed the JS and TS patterns.
fixture=$(make_fixture)
printf '#   Title\n' > "$fixture/project/only.md"
run_runner "$fixture"
markdown_only_status=$?

expect "a project with no JS or TS still exits clean" \
  test "$markdown_only_status" -eq 0

# --- the home config is the fallback ----------------------------------------

fixture=$(make_fixture)
printf '{"semi": false}\n' > "$fixture/home/.prettierrc"
printf 'const a = 1;\n' > "$fixture/project/app.js"
run_runner "$fixture"

expect "a project with no config of its own formats by the home config" \
  test "$(cat "$fixture/project/app.js")" = "const a = 1"

# --- a project's own config wins --------------------------------------------

# The home config asks for the opposite, so the semicolon's absence can only
# come from the project's own file.
fixture=$(make_fixture)
printf '{"semi": true}\n' > "$fixture/home/.prettierrc"
printf '{"semi": false}\n' > "$fixture/project/.prettierrc"
printf 'const a = 1;\n' > "$fixture/project/app.js"
run_runner "$fixture"

expect "a project config wins over the home fallback" \
  test "$(cat "$fixture/project/app.js")" = "const a = 1"

# --- a file prettier cannot parse is breakage -------------------------------

fixture=$(make_fixture)
printf 'const x = {{{\n' > "$fixture/project/broken.ts"
run_runner "$fixture"
unparseable_status=$?

expect "a file prettier cannot parse is breakage, not a finding" \
  test "$unparseable_status" -ge 2
expect "and the error names the file" \
  contains "$(cat "$fixture/stdout")" "broken.ts"

# --- a named target replaces discovery --------------------------------------

fixture=$(make_fixture)
printf '#   Named\n' > "$fixture/project/named.md"
printf '#   Other\n' > "$fixture/project/other.md"
run_runner "$fixture" named.md

expect "a named target is formatted" \
  test "$(head -1 "$fixture/project/named.md")" = "# Named"
expect "and a file that was not named is left alone" \
  test "$(head -1 "$fixture/project/other.md")" = "#   Other"

# --- summary ----------------------------------------------------------------

if [ "$failure_count" -ne 0 ]; then
  echo "quiet-prettier-test: $failure_count assertion(s) failed" >&2
  exit 1
fi
echo "quiet-prettier-test: all assertions passed"
