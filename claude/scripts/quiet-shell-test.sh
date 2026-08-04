#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests which files quiet-shell.sh discovers, and which it leaves alone.
#
# Discovery is the half that fails quietly: a file that is never found is simply
# not formatted, and the output says nothing about it. So every case asserts
# through an observable effect — it writes a fixture file with four-space
# indentation, runs the script, and checks whether the file came back with
# shfmt's two.
#
# Runs the real shfmt and shellcheck against a temporary tree. No network calls,
# so it is safe to run anywhere.

script_dir=$(cd "$(dirname "$0")" && pwd)
quiet_shell="$script_dir/quiet-shell.sh"

. "$script_dir/shell-test-framework.sh"

require_commands shfmt shellcheck

# --- helpers ----------------------------------------------------------------

# Writes a shell file indented four spaces, which shfmt rewrites to two. The
# body is valid in bash and zsh alike, so one shape serves every fixture. A
# first line is written only when given, since zsh startup files carry no
# shebang and are recognized by name instead.
write_misformatted() { # write_misformatted <path> [first-line]
  mkdir -p "$(dirname "$1")"
  : > "$1"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" >> "$1"
  fi
  printf 'if true; then\n    echo hello\nfi\n' >> "$1"
}

# Surviving four-space indentation means the file was never discovered.
was_formatted() { # was_formatted <path>
  ! grep -q '^    echo hello' "$1"
}

was_not_formatted() { # was_not_formatted <path>
  ! was_formatted "$1"
}

# --- cases ------------------------------------------------------------------

# shfmt's own walk supplies these two: a nested file by its extension, and an
# extensionless one by its shebang.
begin_case finds-nested-and-extensionless
write_misformatted "$case_dir/nested/deep.sh" '#!/usr/bin/env bash'
write_misformatted "$case_dir/tool" '#!/usr/bin/env bash'
"$quiet_shell" "$case_dir" > /dev/null 2>&1
expect "formats a nested .sh" was_formatted "$case_dir/nested/deep.sh"
expect "formats an extensionless script with a shebang" \
  was_formatted "$case_dir/tool"

# The find half of discovery: shfmt skips every dot-prefixed file.
begin_case finds-dot-prefixed-files
write_misformatted "$case_dir/.zshrc"
write_misformatted "$case_dir/.helper.sh" '#!/usr/bin/env bash'
"$quiet_shell" "$case_dir" > /dev/null 2>&1
expect "formats .zshrc" was_formatted "$case_dir/.zshrc"
expect "formats a dot-prefixed .sh" was_formatted "$case_dir/.helper.sh"

# A repo's own metadata is not source to format.
begin_case skips-the-git-directory
write_misformatted "$case_dir/.git/hooks/local.sh" '#!/usr/bin/env bash'
write_misformatted "$case_dir/tracked.sh" '#!/usr/bin/env bash'
"$quiet_shell" "$case_dir" > /dev/null 2>&1
expect "formats a file outside .git" was_formatted "$case_dir/tracked.sh"
expect "leaves .git alone" was_not_formatted "$case_dir/.git/hooks/local.sh"

# Only bash is linted: shellcheck has no zsh support. Formatting covers both.
begin_case lints-bash-but-not-zsh
write_misformatted "$case_dir/checked.sh" '#!/usr/bin/env bash'
write_misformatted "$case_dir/.settings.zsh"
# An unguarded cd is SC2164, which shellcheck reports on any bash file.
printf 'cd /tmp\n' >> "$case_dir/checked.sh"
printf 'cd /tmp\n' >> "$case_dir/.settings.zsh"
output=$("$quiet_shell" "$case_dir" 2>&1)
expect "formats the zsh file" was_formatted "$case_dir/.settings.zsh"
expect "reports the finding in the bash file" contains "$output" "checked.sh"
expect "reports nothing for the zsh file" \
  not_contains "$output" ".settings.zsh"

# A named file is checked on its own, without walking its directory.
begin_case accepts-a-single-file
write_misformatted "$case_dir/named.sh" '#!/usr/bin/env bash'
write_misformatted "$case_dir/sibling.sh" '#!/usr/bin/env bash'
"$quiet_shell" "$case_dir/named.sh" > /dev/null 2>&1
expect "formats the named file" was_formatted "$case_dir/named.sh"
expect "leaves its sibling alone" was_not_formatted "$case_dir/sibling.sh"

# Nothing to do is a clean result, and a non-shell file is not shell.
begin_case reports-a-tree-with-no-shell
printf 'notes, not shell\n' > "$case_dir/README.md"
output=$("$quiet_shell" "$case_dir" 2>&1)
exit_code=$?
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "says there is nothing to do" contains "$output" "no shell files"

# A path that does not exist fails loudly rather than passing silently.
begin_case reports-a-missing-path
output=$("$quiet_shell" "$case_dir/absent.sh" 2>&1)
exit_code=$?
expect "exits non-zero" [ "$exit_code" -ne 0 ]
expect "names the missing path" contains "$output" "absent.sh"

# --- summary ----------------------------------------------------------------

report_summary
