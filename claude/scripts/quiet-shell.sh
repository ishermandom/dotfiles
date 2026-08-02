#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean shell runner: format the given paths (default: the current
# directory) with shfmt and lint them with shellcheck, printing one summary line
# when clean and the findings otherwise. Canonical shfmt and shellcheck
# invocation.

# `${#paths[@]}` is the array's element count, so this defaults an empty
# argument list to the current directory.
paths=("$@")
[ ${#paths[@]} -eq 0 ] && paths=(.)

# Discovery is shfmt's own (`shfmt -f`): it matches shell files by extension and
# by shebang, and skips `.git`. It also skips every dot-prefixed file — an
# acknowledged gap upstream rather than a deliberate exclusion — so the
# dot-prefixed shell files rules/shell.md governs are added back by name. The
# two listings are disjoint, so nothing arrives twice. A path that is not a
# directory is taken as a file to check directly, so a caller can name one
# script. (array+=(...) appends an element.)
shell_files=()
for path in "${paths[@]}"; do
  if [ ! -d "$path" ]; then
    shell_files+=("$path")
    continue
  fi
  # `< <(...)` feeds the listing into the loop without a subshell, so the
  # appends below survive it.
  while IFS= read -r found_file; do
    shell_files+=("$found_file")
  done < <(
    shfmt -f "$path"
    find "$path" -path '*/.git' -prune -o -type f \
      \( -name '.zshrc' -o -name '.zprofile' -o -name '.*.bash' \
      -o -name '.*.sh' -o -name '.*.zsh' \) -print
  )
done

if [ ${#shell_files[@]} -eq 0 ]; then
  echo "shell: no shell files"
  exit 0
fi

# The flags are passed rather than left to an `.editorconfig`, because passing
# any formatting flag makes shfmt ignore `.editorconfig` entirely, and this
# script runs in every project — most of which have no such file to read. `-i 2`
# matches the 2-space indentation these repos use, `-ci` indents case branches,
# `-bn` starts a continuation line with `&&` or `||` rather than ending the
# previous line with it, and `-sr` puts a space after a redirect operator,
# keeping `> /dev/null` and `<<< "$input"` spaced.
format_output=$(shfmt -i 2 -ci -bn -sr --write "${shell_files[@]}" 2>&1)
format_status=$?

# Lint only what shellcheck understands: it covers sh, bash, dash, and ksh,
# rejecting zsh outright — and the zsh startup files carry no shebang for it to
# key on, so they come back as an unknown shell. zsh still gets formatted.
lint_files=()
for file in "${shell_files[@]}"; do
  case "$file" in
    *.zsh | *.zshrc | *.zprofile) ;;
    *) lint_files+=("$file") ;;
  esac
done

# `-f gcc` prints one line per finding instead of the default excerpt block,
# which keeps a long finding list readable.
lint_output=""
lint_status=0
if [ ${#lint_files[@]} -gt 0 ]; then
  lint_output=$(shellcheck -f gcc "${lint_files[@]}" 2>&1)
  lint_status=$?
fi

if [ $format_status -eq 0 ] && [ $lint_status -eq 0 ]; then
  echo "shell: ${#shell_files[@]} formatted, ${#lint_files[@]} linted, clean"
else
  [ -n "$format_output" ] && printf '%s\n' "$format_output"
  [ -n "$lint_output" ] && printf '%s\n' "$lint_output"
fi

status=$format_status
[ $lint_status -ne 0 ] && status=$lint_status
exit $status
