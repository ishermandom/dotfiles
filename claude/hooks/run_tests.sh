#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Run the project test suite at the end of every turn.
#
# Runs on Stop rather than PostToolUse (Write|Edit) so that multi-file edits
# that depend on each other aren't flagged mid-turn.
#
# Expects a ./run_tests.sh script at the project root; exits silently if absent.
# When tests fail, blocks the stop turn and feeds the output back as context.
#
# The actual invocation is delegated to the quiet-tests wrapper so the
# canonical flags live in one place (~/.claude/scripts/quiet-tests.sh); its
# short-traceback setting keeps failure feedback token-lean here too.

[ -f ./run_tests.sh ] || exit 0

test_output=$(PYTEST_FROM_HOOK=1 "$HOME/.claude/scripts/quiet-tests.sh" 2>&1)
test_exit_code=$?

[ $test_exit_code -eq 0 ] && exit 0

# jq -Rs reads all of stdin as a single raw string and encodes it as a JSON
# string, safely escaping quotes, newlines, etc.
json_encoded_output=$(printf '%s' "$test_output" | jq -Rs .)

printf '{"continue":false,"stopReason":%s}' "$json_encoded_output"
