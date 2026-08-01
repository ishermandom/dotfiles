#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PreToolUse(Bash) gate: deny bare invocations of the tools the Stop hook
# already runs (pytest, ruff, mypy, prettier), steering intentional runs to the
# token-lean wrappers in ~/.claude/scripts/. The wrappers don't appear in
# command position, so they pass through.
#
# A tool name counts only in *command position* — at the start of a line or
# right after a separator (; | & && ||). Heredoc bodies and quoted strings are
# removed first: a tool name there is data (stdin fed to a heredoc, or an
# argument), never an invocation. Perfect accuracy would need a shell parser;
# the residual gaps (e.g. a literal `<<` inside a quoted argument) only ever
# cause under-gating, which is harmless for an ergonomic guard.
#
# TODO: consider replacing the three regex heuristics (heredoc-body stripping,
# quoted-string stripping, command-position matching) with AST-based parsing via
# `bashlex`, which distinguishes command word from argument/quoted/heredoc data
# structurally and would retire the residual misclassification gaps. Deferred as
# a robustness upgrade, not a fix: the regex approach has zero dependencies and
# degrades safely (under-gates only). bashlex would add a third-party dependency
# to this every-Bash-call hook — installed in the hook's python3 runtime, with
# explicit fail-open on a missing dep or parse error — plus per-call parse
# overhead.

import json
import re
import sys
from typing import TextIO

# A heredoc opener. The body that follows on subsequent lines is stdin data, so
# _strip_heredoc_bodies removes it before matching.
_HEREDOC_OPENER = re.compile(
  r"""
  <<            # the heredoc operator
  (-?)          # group 1: '-' lets the closing delimiter be tab-indented
  \s*           # optional whitespace between << and the delimiter
  ['"]?         # the delimiter may be quoted on the opener (quote not captured)
  (\w+)         # group 2: the delimiter word
  """,
  re.VERBOSE,
)

# A single- or double-quoted string. Its contents are an argument, never a
# command, so _strip_quoted_strings removes the whole span before matching.
_QUOTED_STRING = re.compile(
  r"""
    "                  # opening double quote
    (?: \\. | [^"\\] )* # body: an escaped pair (\\. spans \" etc.) or any
                        #   character that is neither a quote nor a backslash
    "                  # closing double quote
  |                    # ── or ──
    '                  # opening single quote
    [^']*              # body: anything but a quote (no escapes inside '...')
    '                  # closing single quote
  """,
  re.VERBOSE | re.DOTALL,  # DOTALL: a quoted string may span newlines
)

# A gated tool in command position. The matcher runs after quotes and heredoc
# bodies are stripped, so any separator here is a real one.
_COMMAND_POSITION = re.compile(
  r"""
  (?: ^ | [;|&] )            # a line start, or just after a separator
                             #   (& covers && and a background &; | covers ||)
  \s*                        # optional whitespace before the command word
  (?:
      pytest
    | python3? \s+ -m \s+ pytest  # `python -m pytest` / `python3 -m pytest`
    | ruff
    | mypy
    | prettier
  )
  (?: \s | $ )               # trailing boundary: whitespace or end of line, so
                             #   `ruff/x` (a path) and `mypyc` don't match
  """,
  re.VERBOSE | re.MULTILINE,  # MULTILINE: ^ matches the start of every line
)

_DENY_REASON = (
  'pytest, ruff, mypy, and prettier run automatically at Stop — do not re-run '
  'them reflexively mid-turn. If this run adds value (e.g. confirming an '
  'intermediate state lets more work land this turn), use the token-lean '
  'wrappers instead: ~/.claude/scripts/quiet-{tests,mypy,ruff,prettier}.sh '
  '[paths]. Their output is shown to the user automatically.'
)


def _strip_heredoc_bodies(command: str) -> str:
  """Drop heredoc bodies, which are stdin data rather than commands.

  Opener lines (which carry the real command) and anything after a closing
  delimiter are kept; only the body lines between them are removed. A close line
  is the bare delimiter word — quotes only ever appear on the opener.
  """
  kept_lines: list[str] = []
  # Delimiters whose bodies are currently being consumed, in FIFO order; each
  # records whether `<<-` permits a tab-indented closing delimiter.
  pending: list[tuple[str, bool]] = []
  for line in command.split('\n'):
    if pending:
      delimiter, allows_indent = pending[0]
      candidate = line.lstrip('\t') if allows_indent else line
      if candidate == delimiter:
        pending.pop(0)  # closing delimiter line — drop it too
      continue  # body or close line: never a command, so drop it
    kept_lines.append(line)  # opener or ordinary line: keep it
    for indent, delimiter in _HEREDOC_OPENER.findall(line):
      pending.append((delimiter, indent == '-'))
  return '\n'.join(kept_lines)


def _strip_quoted_strings(command: str) -> str:
  """Remove single- and double-quoted spans — arguments, never commands."""
  return _QUOTED_STRING.sub('', command)


def _runs_gated_tool(command: str) -> bool:
  """Whether the command invokes a gated tool in command position."""
  data_free = _strip_quoted_strings(_strip_heredoc_bodies(command))
  return _COMMAND_POSITION.search(data_free) is not None


def main(stdin: TextIO = sys.stdin, stdout: TextIO = sys.stdout) -> None:
  """Read the hook payload from `stdin`; emit any deny decision to `stdout`.

  Emits nothing when the command runs no gated tool, so the call falls through
  to settings.json and the normal prompt. The streams are parameters so the gate
  can be driven in memory from tests.
  """
  try:
    payload = json.load(stdin)
  except json.JSONDecodeError:
    return  # unparseable payload: fail open — this is an ergonomic gate

  # A payload the gate cannot read a command out of fails open for the same
  # reason: an ergonomic guard never blocks a call whose shape it can't parse.
  tool_input = payload.get('tool_input') if isinstance(payload, dict) else None
  command = tool_input.get('command') if isinstance(tool_input, dict) else None
  if not isinstance(command, str):
    return

  if not _runs_gated_tool(command):
    return

  decision = {
    'hookSpecificOutput': {
      'hookEventName': 'PreToolUse',
      'permissionDecision': 'deny',
      'permissionDecisionReason': _DENY_REASON,
    }
  }
  json.dump(decision, stdout, ensure_ascii=False)


if __name__ == '__main__':
  main()
