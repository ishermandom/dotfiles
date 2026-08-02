# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the auto-tools gate, exercised through its only public entry
# point — main() reading a hook payload from stdin and writing a decision to
# stdout.

import io
import json

import gate_auto_tools
import pytest

# --- helpers: drive the gate through its main() entry point ---


def _run_gate_on_raw_stdin(stdin_text: str) -> str:
  """main()'s stdout for arbitrary raw stdin (for malformed-payload tests)."""
  stdout = io.StringIO()
  gate_auto_tools.main(stdin=io.StringIO(stdin_text), stdout=stdout)
  return stdout.getvalue()


def _run_gate(command: str) -> str:
  """main()'s stdout for a Bash payload carrying `command`."""
  return _run_gate_on_raw_stdin(
    json.dumps({'tool_input': {'command': command}})
  )


def _decision_for(command: str) -> str | None:
  """The permissionDecision main() emits for `command`.

  None when main() emits nothing — the command runs no gated tool, so it falls
  through to settings.json and the normal prompt.
  """
  raw = _run_gate(command)
  if not raw:
    return None
  decision = json.loads(raw)['hookSpecificOutput']['permissionDecision']
  assert isinstance(decision, str)
  return decision


# --- a gated tool in command position is denied ---

# Commands that genuinely invoke a gated tool in command position.
DENYLISTED: tuple[str, ...] = (
  'mypy src/',
  'ruff check .',
  'pytest -q',
  'python -m pytest',
  'python3 -m pytest',
  'cd /repo && mypy',  # after && separator
  'echo hi | ruff check -',  # after | separator
  'ruff check .\nmypy src/',  # tool at the start of a later line
)

# --- wrappers, data, and path fragments defer to the prompt ---

# Commands that must pass: the wrappers, data (quoted args, heredoc bodies), and
# tool names appearing as path fragments rather than commands.
DEFERRED: tuple[str, ...] = (
  '~/.claude/scripts/quiet-ruff.sh .',
  '~/.claude/scripts/quiet-mypy.sh',
  'git add ruff/pyproject.toml',  # path fragment, not a command
  'git commit -m "note: mypy is not the authority; ruff stays the gate"',
  # Heredoc commit message — the case that misfired before the rewrite:
  "git commit -F - <<'EOF'\nnot bug-catching; mypy is not the authority\nEOF",
  # Heredoc body line that *starts* with a tool name:
  'cat <<EOF\nruff check .\nEOF',
  # Commands after a heredoc close are still scanned:
  "cat <<'EOF'\nbody\nEOF\necho done",
)


@pytest.mark.parametrize('command', DENYLISTED)
def test_tool_in_command_position_is_denied(command: str) -> None:
  """A genuine invocation is denied, wherever it sits in the command."""
  assert _decision_for(command) == 'deny'


@pytest.mark.parametrize('command', DEFERRED)
def test_wrapper_or_data_occurrence_defers(command: str) -> None:
  """A wrapper, quoted argument, heredoc body, or path fragment defers."""
  assert _decision_for(command) is None


# --- main()'s emitted JSON carries the right shape ---


def test_deny_carries_a_reason() -> None:
  output = json.loads(_run_gate('pytest -q'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'deny'
  assert 'wrappers' in output['permissionDecisionReason']


# --- fail-open: a payload the gate can't read never blocks the call ---

# Shapes that carry no readable command. The gate is ergonomic, not a security
# boundary, so every one of them emits nothing rather than denying on a guess.
UNREADABLE_PAYLOADS: tuple[str, ...] = (
  'not json at all',
  '[]',  # valid JSON, but not an object
  '{}',  # an object with no tool_input
  '{"tool_input": null}',  # tool_input present but not an object
  '{"tool_input": {"command": 123}}',  # command present but not a string
)


@pytest.mark.parametrize('stdin_text', UNREADABLE_PAYLOADS)
def test_unreadable_payload_emits_nothing(stdin_text: str) -> None:
  """A payload with no readable command falls through instead of denying."""
  assert _run_gate_on_raw_stdin(stdin_text) == ''
