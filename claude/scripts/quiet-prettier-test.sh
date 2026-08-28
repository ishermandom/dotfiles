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

. "$script_dir/shell-test-framework.sh"

require_commands prettier git

# --- case helpers -----------------------------------------------------------

# Begins a case whose directory holds a project to format, plus a fake HOME to
# resolve the script's global-config fallback against.
#
# The empty global config keeps that fallback pointing at a real file, since
# prettier errors on a --config path that does not exist. The case about the
# fallback overwrites it with a setting it can observe.
begin_project_case() { # begin_project_case <name>
  begin_case "$1"
  mkdir -p "$case_dir/home" "$case_dir/project"
  printf '{}\n' > "$case_dir/home/.prettierrc"
}

# Runs the runner inside the case's project against its fake HOME, leaving both
# streams in the case directory as stdout. Returns the runner's exit status,
# which is the level claude/hooks/format.sh reads. TMPDIR points at the case so
# the runner's prettier cache is built and left inside it, rather than in the
# one the machine's real runs share.
run_runner() { # run_runner [runner arguments...]
  (cd "$case_dir/project" && HOME="$case_dir/home" TMPDIR="$case_dir" \
    "$quiet_prettier" "$@") > "$case_dir/stdout" 2>&1
}

# --- cases ------------------------------------------------------------------

begin_project_case reports-nothing-to-format
echo "notes" > "$case_dir/project/notes.txt"
run_runner
exit_code=$?

expect "a project with nothing to format exits clean" test "$exit_code" -eq 0
expect "and says so in its own words" \
  contains "$(cat "$case_dir/stdout")" "no formattable files"

begin_project_case finds-nested-files
mkdir -p "$case_dir/project/nested"
printf '#   Title\n' > "$case_dir/project/nested/doc.md"
run_runner

expect_equal "a markdown file in a subdirectory is reformatted" \
  "$(head -1 "$case_dir/project/nested/doc.md")" "# Title"

# Prettier errors on a glob that matches nothing, so a project carrying only
# markdown must not be handed the JS and TS patterns.
begin_project_case globs-only-the-extensions-present
printf '#   Title\n' > "$case_dir/project/only.md"
run_runner
exit_code=$?

expect "a project with no JS or TS still exits clean" test "$exit_code" -eq 0

# The runner does not read gitignore rules when deciding which patterns to
# offer, which is safe only because prettier tolerates a pattern whose matches
# are all ignored files: the pattern did match on disk and so does not count as
# unmatched, and the ignored files drop out afterwards.
#
# That is an assumption about prettier rather than about the runner, which is
# why it is pinned here. Should prettier ever count such a pattern as unmatched,
# the runner would start reporting breakage on healthy projects, and this case
# is what would say so first.
begin_project_case tolerates-a-fully-gitignored-extension
git -C "$case_dir/project" init -q
printf 'vendor.js\n' > "$case_dir/project/.gitignore"
printf 'const a   =   1;\n' > "$case_dir/project/vendor.js"
printf '#   Title\n' > "$case_dir/project/doc.md"
run_runner
exit_code=$?

expect "a project whose only JS is gitignored exits clean" \
  test "$exit_code" -eq 0
expect_equal "and its markdown is still formatted" \
  "$(head -1 "$case_dir/project/doc.md")" "# Title"
expect_equal "and the gitignored file is left alone" \
  "$(cat "$case_dir/project/vendor.js")" "const a   =   1;"

# Prettier drops node_modules while expanding the glob, so an extension found
# only there would produce a pattern matching nothing — the error the runner's
# pattern check exists to head off.
begin_project_case skips-an-extension-only-inside-node-modules
mkdir -p "$case_dir/project/node_modules"
printf 'const a   =   1;\n' > "$case_dir/project/node_modules/vendor.js"
printf '#   Title\n' > "$case_dir/project/doc.md"
run_runner
exit_code=$?

expect "a project whose only JS is vendored exits clean" test "$exit_code" -eq 0
expect_equal "and the vendored file is left alone" \
  "$(cat "$case_dir/project/node_modules/vendor.js")" "const a   =   1;"

begin_project_case falls-back-to-the-home-config
printf '{"semi": false}\n' > "$case_dir/home/.prettierrc"
printf 'const a = 1;\n' > "$case_dir/project/app.js"
run_runner

expect_equal "a project with no config of its own formats by the home config" \
  "$(cat "$case_dir/project/app.js")" "const a = 1"

# The home config asks for the opposite, so the semicolon's absence can only
# come from the project's own file.
begin_project_case prefers-the-project-config
printf '{"semi": true}\n' > "$case_dir/home/.prettierrc"
printf '{"semi": false}\n' > "$case_dir/project/.prettierrc"
printf 'const a = 1;\n' > "$case_dir/project/app.js"
run_runner

expect_equal "a project config wins over the home fallback" \
  "$(cat "$case_dir/project/app.js")" "const a = 1"

begin_project_case reports-an-unparseable-file
printf 'const x = {{{\n' > "$case_dir/project/broken.ts"
run_runner
exit_code=$?

expect "a file prettier cannot parse is breakage, not a finding" \
  test "$exit_code" -ge 2
expect "and the error names the file" \
  contains "$(cat "$case_dir/stdout")" "broken.ts"

begin_project_case formats-only-a-named-target
printf '#   Named\n' > "$case_dir/project/named.md"
printf '#   Other\n' > "$case_dir/project/other.md"
run_runner named.md

expect_equal "a named target is formatted" \
  "$(head -1 "$case_dir/project/named.md")" "# Named"
expect_equal "and a file that was not named is left alone" \
  "$(head -1 "$case_dir/project/other.md")" "#   Other"

# Discovery leaves out an extension with no files; a named target gets no such
# forgiveness. Letting prettier's complaint pass as success would be the silent
# clean turn the level scale exists to prevent.
begin_project_case reports-a-missing-named-target
run_runner gone.md
exit_code=$?

expect "a named target that is not there is breakage" test "$exit_code" -ge 2
expect "and the error names the missing target" \
  contains "$(cat "$case_dir/stdout")" "gone.md"

# The runner caches what prettier has already formatted, which is only safe
# while the cache cannot stand between an edit and the formatter. Both cases
# below run the runner twice against one case directory, and so against one
# cache.
begin_project_case reformats-a-file-the-cache-has-seen
printf '#   Title\n' > "$case_dir/project/doc.md"
run_runner
printf '#   Changed\n' > "$case_dir/project/doc.md"
run_runner

expect_equal "a file edited after being cached is formatted again" \
  "$(head -1 "$case_dir/project/doc.md")" "# Changed"

# The file is already formatted under the first config, so the first run leaves
# it alone and caches it as it stands. Nothing but the config change can explain
# it being rewritten after that.
begin_project_case reformats-when-the-config-changes
printf '{"semi": true}\n' > "$case_dir/home/.prettierrc"
printf 'const a = 1;\n' > "$case_dir/project/app.js"
run_runner
printf '{"semi": false}\n' > "$case_dir/home/.prettierrc"
run_runner

expect_equal "a changed config reaches a file the cache had seen" \
  "$(cat "$case_dir/project/app.js")" "const a = 1"

# --- summary ----------------------------------------------------------------

exit_with_summary
