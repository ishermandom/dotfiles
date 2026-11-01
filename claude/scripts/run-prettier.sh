#!/bin/bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Runs prettier with the given arguments, under Bun where Bun is installed.
#
# Bun formats byte for byte identically to Node, but starts far faster:
# Homebrew's Node spends about 70ms of every launch loading the shared libraries
# it links, measured 2026-11-01. Homebrew's `prettier` is a JavaScript file
# whose first line names Node; handed that file, Bun runs it in Node's place.
# Without Bun, or without prettier, the plain `prettier` command runs, so a
# missing prettier still fails with the shell's 127. Prettier's cache key
# includes the runtime's version, so a change of runtime starts the cache
# afresh.
#
# The shebang names `/bin/bash` rather than going through `env`, because this
# script starts before every prettier launch, and Apple's bash starts several
# times faster than Homebrew's. `exec` then replaces this shell with prettier,
# so nothing lingers. Bun and prettier are found on the caller's PATH; the
# script adds no directory of its own.
#
# Usage: run-prettier.sh [prettier argument...]

prettier_path=$(command -v prettier)
if [ -n "$prettier_path" ] && command -v bun > /dev/null; then
  exec bun "$prettier_path" "$@"
fi
exec prettier "$@"
