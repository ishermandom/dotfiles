#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Puts Homebrew's bin directory, where Homebrew installs its tools, on PATH. The
# directory is on PATH only when a login shell put it there, and not every
# caller starts from one.
#
# Appended rather than prepended, so a tool earlier on PATH still wins: a test
# can substitute a stub for a real tool that way, to produce an outcome the real
# tool cannot.
#
# Sourced rather than run, since only a sourced file can change the PATH of the
# script that reads it. The shebang only names the dialect for shellcheck and
# editors, and the file is deliberately not executable.

export PATH="$PATH:/opt/homebrew/bin"
