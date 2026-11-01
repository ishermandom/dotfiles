#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean prettier runner: format the given targets (default: every
# Markdown/JS/TS file under the current directory that git does not ignore),
# printing one line on success and prettier's errors otherwise. Canonical
# prettier invocation — the Stop hook delegates here.

# Hooks and subshells may run with a minimal environment; Homebrew's bin
# directory may not be on PATH, so add it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

# Lists the files to format by default, each ending in a NUL byte.
#
# In a git repo, git lists them:
#
# - `--cached`: the tracked files; the index is what git calls its cache
# - `--others`: the untracked files too
# - `--exclude-standard`: minus any untracked file an ignore rule covers. Git
#   reads every ignore source — each folder's `.gitignore`, `.git/info/exclude`,
#   the global excludes file — where prettier reads only the `.gitignore` in the
#   directory it runs from.
# - `-z`: each path ends in a NUL byte rather than a newline, and an unusual
#   name comes unquoted, so any name arrives whole
#
# Outside a repo, git fails without listing anything, and `find` lists the files
# instead. Its tests join with an implied AND, and `-o` means OR, so the
# expression offers two alternatives. A folder named node_modules is pruned,
# skipped wholesale, as prettier would skip it. Anything else is printed, with a
# NUL ending, if it is a regular file (`-type f`) whose name matches one of the
# three patterns; the parentheses keep those three ORs inside the second
# alternative.
list_default_targets() {
  git ls-files -z --cached --others --exclude-standard \
    -- '*.md' '*.js' '*.ts' 2> /dev/null \
    || find . -name node_modules -prune -o -type f \
      \( -name '*.md' -o -name '*.js' -o -name '*.ts' \) -print0
}

if [ $# -gt 0 ]; then
  targets=("$@")
else
  # Hand prettier the files themselves, not patterns such as `**/*.md`. Given a
  # pattern, prettier would expand it by walking every folder, ignored ones
  # included, and apply ignore rules only afterwards. In a checkout whose
  # ignored `.claude/` holds other worktrees, that walk alone would cost more
  # than the formatting.
  #
  # `read -d ''` takes one NUL-ended path at a time, so a name holding spaces or
  # newlines stays whole. `IFS=` empties the shell's field separators for this
  # one `read`, which would otherwise trim a name's leading and trailing spaces,
  # and `-r` keeps backslashes literal. `< <(...)` feeds the loop the listing
  # while keeping the loop in this shell; piped into, the loop would run in a
  # subshell, and `targets` would come back empty.
  targets=()
  while IFS= read -r -d '' path; do
    # Prettier rejects a named file that is missing or a symlink, where its
    # expansion skips both. Git still lists a tracked file deleted from the
    # working tree, and lists a tracked symlink like any other file.
    if [ -f "$path" ] && [ ! -L "$path" ]; then
      targets+=("$path")
    fi
  done < <(list_default_targets)
  [ ${#targets[@]} -eq 0 ] && {
    echo "prettier: no formattable files"
    exit 0
  }
fi

# Prettier runs under Bun where Bun is installed. Bun formats byte for byte as
# Node does but starts far faster: Homebrew's Node spends about 70ms of every
# launch loading the shared libraries it links, measured 2026-11-01, and this
# script launches prettier twice. Bun runs the launcher Homebrew's `prettier`
# links to, ignoring the Node its first line names. Without Bun, or without
# prettier, the plain command runs, so a missing prettier still fails with the
# shell's 127.
#
# Prettier's cache key includes the runtime's version, so runs sharing a cache
# should share a runtime. The per-edit Markdown hook formats through this script
# too, so the two always agree.
prettier_command=(prettier)
prettier_path=$(command -v prettier)
if [ -n "$prettier_path" ] && command -v bun > /dev/null; then
  prettier_command=(bun "$prettier_path")
fi

# Fall back to the global config when no project-level config exists, which is
# when `--find-config-path` fails.
config_args=()
"${prettier_command[@]}" --find-config-path ./placeholder > /dev/null 2>&1
config_search_status=$?
if [ "$config_search_status" -ne 0 ]; then
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

output=$("${prettier_command[@]}" "${config_args[@]}" "${cache_args[@]}" \
  --log-level warn --write "${targets[@]}" 2>&1)
status=$?

if [ $status -eq 0 ]; then
  echo "prettier: ok"
else
  echo "$output"
fi
exit $status
