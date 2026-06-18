#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Test suite for the dotfiles repo — the hook unit tests under claude/hooks.
# Run directly, or via ~/.claude/scripts/quiet-tests.sh (which the Stop test
# hook invokes). Honors PYTEST_ADDOPTS, which the quiet wrapper sets to
# --tb=short. pytest discovery config (testpaths, pythonpath) lives in the root
# pyproject.toml. Extra arguments are forwarded to pytest.

# Resolve the hooks directory against the script's own location so the suite
# runs identically regardless of the caller's working directory; per the
# testing convention we never cd.
exec python3 -m pytest "$(dirname "$0")/claude/hooks" "$@"
