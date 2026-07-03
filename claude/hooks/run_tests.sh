#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Run the project test suite at the end of every turn.
#
# Runs on Stop rather than PostToolUse (Write|Edit) so that multi-file edits
# that depend on each other aren't flagged mid-turn.
#
# Expects a ./run_tests.sh script at the project root; exits silently if
# absent. When tests fail, halts the stop and shows the output to the user;
# Claude sees it alongside the user's next message and fixes from there.
# Deliberately not a decision:block auto-re-invoke: a block can spin forever
# when Claude cannot fix the failure, guarding against that is out of scope
# for now, and the workaround is trivial — the user prods the next turn and
# the fix proceeds.
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
