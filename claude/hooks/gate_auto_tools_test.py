#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for the auto-tools gate. Run from the hooks directory, or with it on
# PYTHONPATH: PYTHONPATH=~/.claude/hooks python3
# ~/.claude/hooks/gate_auto_tools_test.py

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


def test_gated_commands_are_denied() -> None:
  """Every genuine in-command-position invocation is gated."""
  for command in GATED:
    assert runs_gated_tool(command), f'expected gated: {command!r}'


def test_data_and_wrappers_pass() -> None:
  """Wrappers, quoted args, heredoc bodies, and path fragments pass."""
  for command in ALLOWED:
    assert not runs_gated_tool(command), f'expected allowed: {command!r}'


def main() -> None:
  """Run the assertions directly (no pytest dependency required)."""
  test_gated_commands_are_denied()
  test_data_and_wrappers_pass()
  print('all gate_auto_tools tests passed')


if __name__ == '__main__':
  main()
