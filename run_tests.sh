#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Test suite for the dotfiles repo — the unit tests under claude/hooks and
# claude/scripts.
# Run directly, or via ~/.claude/scripts/quiet-tests.sh (which the Stop test
# hook invokes). Honors PYTEST_ADDOPTS, which the quiet wrapper sets to
# --tb=short. pytest discovery config (testpaths, pythonpath) lives in the root
# pyproject.toml. Extra arguments are forwarded to pytest.

# Resolve the test directories against the script's own location so the suite
# runs identically regardless of the caller's working directory; per the
# testing convention we never cd.
root="$(dirname "$0")"
exec python3 -m pytest "$root/claude/hooks" "$root/claude/scripts" "$@"
