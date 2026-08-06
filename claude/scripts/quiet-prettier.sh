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

output=$(prettier "${config_args[@]}" --log-level warn \
  --write "${targets[@]}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "prettier: ok"
else
  echo "$output"
fi
exit $status
