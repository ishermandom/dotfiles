#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean prettier runner: format the given targets (default: all
# Markdown/JS/TS under the current directory), printing one line on success and
# prettier's errors otherwise. Canonical prettier invocation — the Stop hook
# delegates here.

# Hooks and subshells may run with a minimal environment; Homebrew's bin
# directory may not be on PATH, so add it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

if [ $# -gt 0 ]; then
  targets=("$@")
else
  # Prettier treats a glob that matches nothing as an error, so a pattern is
  # offered only once a file of that type is known to exist. That error keeps a
  # typo in one of the patterns below from quietly formatting nothing.
  #
  # Guessing which patterns match means seeing the tree the way prettier does.
  # Seeing more of the tree than prettier does means offering a pattern prettier
  # then finds empty — the error this check exists to head off. Only
  # `node_modules` has to be accounted for: prettier drops vendored trees while
  # expanding the glob, so a pattern matching nothing else is unmatched from
  # prettier's point of view. Ignore rules (`.gitignore`, `.prettierignore`)
  # apply after matching instead, so a pattern whose every match they exclude
  # still counts as matched, and costs a prettier run that reformats nothing
  # rather than an error.
  targets=()
  for pattern in '*.md' '*.js' '*.ts'; do
    # -prune skips node_modules wholesale, and -quit ends the walk at the first
    # hit, since presence is the only question being asked.
    first_match=$(find . -name node_modules -prune -o \
      -name "$pattern" -print -quit 2> /dev/null)
    if [ -n "$first_match" ]; then
      targets+=("**/${pattern}")
    fi
  done
  [ ${#targets[@]} -eq 0 ] && {
    echo "prettier: no formattable files"
    exit 0
  }
fi

# Fall back to the global config when no project-level config exists.
config_args=()
if ! prettier --find-config-path ./placeholder > /dev/null 2>&1; then
  config_args=(--config "$HOME/.prettierrc")
fi

# Prettier reparses every file it is handed, while a typical turn changes only
# one or two files, so let prettier skip what it has already seen. Caching takes
# this step from about 500ms to about 165ms, measured on this repo 2026-08-31.
#
# `content` rather than the default `metadata` strategy: metadata keys a file on
# its size and its modification time in milliseconds, and one millisecond
# comfortably holds two writes, so a same-length rewrite can leave both
# unchanged and the file unformatted. Hashing the contents measured no slower,
# so the stricter key costs nothing.
#
# One cache per formatted directory, because prettier records each path it was
# handed relative to the directory the run started in — one shared cache would
# leave two projects arguing over the entry for `README.md`. The user id keeps
# the `/tmp` fallback, used when TMPDIR is unset, from colliding between this
# machine's accounts.
cache_dir="${TMPDIR:-/tmp}/prettier-cache-$UID"
mkdir -p "$cache_dir"
cache_args=(--cache --cache-strategy content
  --cache-location "$cache_dir/$(printf '%s' "$PWD" | md5 -q)")

output=$(prettier "${config_args[@]}" "${cache_args[@]}" --log-level warn \
  --write "${targets[@]}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "prettier: ok"
else
  echo "$output"
fi
exit $status
