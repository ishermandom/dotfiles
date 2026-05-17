#!/usr/bin/env bash
# Format and lint-fix all Python files in the current directory.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits
# from the turn have landed before formatting runs. The Stop hook receives
# no information about which files changed, so we check the whole directory.

has_python_files=$(find . -name "*.py" -quit 2>/dev/null)
[ -z "$has_python_files" ] && exit 0

# 2>/dev/null discards stderr (e.g. "cannot parse file") so that ruff
# warnings don't surface as hook errors. The main case where ruff errors —
# unparseable files — is already caught by mypy. Non-auto-fixable lint
# issues go to stdout and are unaffected. Unexpected ruff crashes would be
# silently missed, but that is unlikely in practice.
ruff check --fix . 2>/dev/null
ruff format . 2>/dev/null
