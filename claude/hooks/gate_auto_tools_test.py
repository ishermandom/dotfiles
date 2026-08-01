#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the auto-tools gate, exercised through its command-position
# predicate, runs_gated_tool. Run with the hooks directory on PYTHONPATH:
# PYTHONPATH=~/.claude/hooks pytest ~/.claude/hooks/gate_auto_tools_test.py

import pytest
from gate_auto_tools import runs_gated_tool

# Commands that genuinely invoke a gated tool in command position.
GATED: tuple[str, ...] = (
  'mypy src/',
  'ruff check .',
  'pytest -q',
  'python -m pytest',
  'python3 -m pytest',
  'cd /repo && mypy',  # after && separator
  'echo hi | ruff check -',  # after | separator
  'ruff check .\nmypy src/',  # tool at the start of a later line
)

# Commands that must pass: the wrappers, data (quoted args, heredoc bodies), and
# tool names appearing as path fragments rather than commands.
ALLOWED: tuple[str, ...] = (
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


@pytest.mark.parametrize('command', GATED)
def test_tool_in_command_position_is_gated(command: str) -> None:
  """A genuine invocation is gated, wherever it sits in the command."""
  assert runs_gated_tool(command)


@pytest.mark.parametrize('command', ALLOWED)
def test_wrapper_or_data_occurrence_passes(command: str) -> None:
  """A wrapper, quoted argument, heredoc body, or path fragment passes."""
  assert not runs_gated_tool(command)
