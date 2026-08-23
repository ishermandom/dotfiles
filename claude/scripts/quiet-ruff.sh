#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean ruff runner: lint-fix and format the given paths (default: the
# current directory), printing one summary line when clean and the remaining
# issues otherwise. Canonical ruff invocation — the Stop hook delegates here.
#
# Why cd to the repo root: ruff's isort infers first- vs third-party imports
# from the package layout around where it runs. From a package subdirectory it
# can't see the top-level package and sorts the project's own imports as
# third-party. Running from the repo root fixes that. The root comes from the
# target paths' repo, not the current directory, because the Stop hook formats
# two repos in one turn — the project and the dotfiles checkout. Outside a repo,
# run in place.

# Hooks and subshells may run with a minimal environment; Homebrew's bin
# directory may not be on PATH, so append it. uv lives there, and every
# invocation below goes through it. Appended rather than prepended so that a uv
# placed earlier on PATH still wins: `quiet-ruff-test.sh` substitutes a stub
# that way to produce a check/format status pairing real ruff cannot.
export PATH="$PATH:/opt/homebrew/bin"

paths=("$@")
[ ${#paths[@]} -eq 0 ] && paths=(.)

# A path that does not exist is caught here rather than downstream, where
# realpath yields an empty string that then reads as a missing argument by the
# time ruff sees it. Naming the path beats three messages about its remains.
for path in "${paths[@]}"; do
  if [ ! -e "$path" ]; then
    echo "ruff: no such path: $path" >&2
    exit 2
  fi
done

# Ruff warns "No Python files found under the given path(s)" and exits 0 when
# there is nothing to check, which is noise rather than a result. -print -quit
# stops find after the first match, for speed.
has_python_files=$(find "${paths[@]}" -name "*.py" -print -quit 2> /dev/null)
[ -z "$has_python_files" ] && {
  echo "ruff: no Python files"
  exit 0
}

# Resolve targets to absolute paths so they stay valid after the cd below.
abs_paths=()
for path in "${paths[@]}"; do
  abs_paths+=("$(realpath "$path")")
done

# Anchor on the first target's repo root. git rev-parse must run from a
# directory, so step up when the target is a file. The ":-" fallback runs in
# place when the target is not in a git repo.
first_dir=${abs_paths[0]}
[ -f "$first_dir" ] && first_dir=$(dirname "$first_dir")
repo_root=$(cd "$first_dir" && git rev-parse --show-toplevel 2> /dev/null)
run_dir="${repo_root:-$PWD}"

# Reach ruff through uv rather than through PATH, so the version is whatever the
# target repo pins rather than whatever a venv happens to have been activated.
# `--project` names the repo explicitly, so uv resolves that project and never
# walks past it into an unrelated one above. `--with` supplies a ruff for a repo
# that declares none — it does not override a declared pin, so a repo that pins
# one still gets it.
#
# uv syncs the project before running, which is what makes the pin take effect.
# In a repo that declares dependencies but has no lockfile yet, that writes one.
ruff=(uv run --project "$run_dir" --with ruff ruff)

# Each cd runs in its command-substitution subshell, so the script's own
# directory is unaffected.
check_output=$(cd "$run_dir" && "${ruff[@]}" check --fix "${abs_paths[@]}" 2>&1)
check_status=$?
format_output=$(cd "$run_dir" && "${ruff[@]}" format "${abs_paths[@]}" 2>&1)
format_status=$?

if [ $check_status -eq 0 ] && [ $format_status -eq 0 ]; then
  echo "$format_output" | tail -1
else
  printf '%s\n%s\n' "$check_output" "$format_output"
fi

# The worse of the two statuses wins, so a breakage never hides behind the other
# invocation's findings. Callers read the status by level rather than as a bare
# pass/fail — see the exit-status scales in claude/hooks/format.sh.
status=$check_status
[ $format_status -gt $status ] && status=$format_status
exit $status
