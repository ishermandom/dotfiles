#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean prettier runner: format the given targets (default: all
# Markdown/JS/TS under the current directory), printing one line on success
# and prettier's errors otherwise. Canonical prettier invocation — the Stop
# hook delegates here.

# Hooks and subshells may run with a minimal environment; Homebrew's bin
# directory may not be on PATH, so add it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

if [ $# -gt 0 ]; then
  targets=("$@")
else
  # Prettier errors on glob patterns with no matches, so only include the
  # extensions actually present.
  targets=()
  for pattern in '*.md' '*.js' '*.ts'; do
    if [ -n "$(find . -name "$pattern" -print -quit 2>/dev/null)" ]; then
      targets+=("**/${pattern}")
    fi
  done
  [ ${#targets[@]} -eq 0 ] && { echo "prettier: no formattable files"; exit 0; }
fi

# Fall back to the global config when no project-level config exists.
config_args=()
if ! prettier --find-config-path ./placeholder >/dev/null 2>&1; then
  config_args=(--config "$HOME/.prettierrc")
fi

output=$(prettier "${config_args[@]}" --log-level warn --write "${targets[@]}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "prettier: ok"
else
  echo "$output"
fi
exit $status
