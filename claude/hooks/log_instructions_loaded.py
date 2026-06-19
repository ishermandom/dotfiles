#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# InstructionsLoaded hook: record each InstructionsLoaded payload so it's
# possible to debug after the fact which instruction files (CLAUDE.md, the
# rules/ files) actually loaded for a session. Each block is a timestamp header
# followed by the pretty-printed payload, appended to instructions-loaded.log.
#
# The log self-rotates via the shared log_rotation helper, so this debug history
# stays bounded without manual cleanup.

import json
import sys
from datetime import UTC, datetime
from pathlib import Path

import log_rotation

# Where InstructionsLoaded payloads accumulate, alongside the other ~/.claude
# logs.
LOG_PATH = Path('~/.claude/logs/instructions-loaded.log').expanduser()

# Rotate the active log once it crosses this size. Modest because this is a
# disposable debug trace, not analysis material — recent blocks are what matter.
MAX_ACTIVE_BYTES = 64 * 1024

# Cap total disk for the active log plus all retained archives. Smaller than the
# permission-prompt budget: old rule-loading history has little lasting value.
TOTAL_BUDGET_BYTES = 512 * 1024


def format_block(raw_input: str, timestamp: str) -> str:
  """Format one log block: timestamp header, the payload, a trailing blank line.

  Pretty-prints the payload when it parses as JSON; falls back to the raw text
  otherwise, so a malformed payload is still recorded rather than dropped.
  """
  try:
    payload = json.loads(raw_input)
  except json.JSONDecodeError:
    body = raw_input.rstrip('\n')  # preserve as-is; just trim trailing blanks
  else:
    body = json.dumps(payload, indent=2, ensure_ascii=False)
  return f'[{timestamp}]\n{body}\n\n'


def record(raw_input: str, log_path: Path) -> None:
  """Append one timestamped block for the payload, then rotate if oversized."""
  timestamp = datetime.now(UTC).strftime('%Y-%m-%dT%H:%M:%SZ')
  log_path.parent.mkdir(parents=True, exist_ok=True)
  with log_path.open('a', encoding='utf-8') as log:
    log.write(format_block(raw_input, timestamp))
  log_rotation.rotate_if_needed(log_path, MAX_ACTIVE_BYTES, TOTAL_BUDGET_BYTES)


def main() -> None:
  """Read the hook payload from stdin and append it to the log."""
  record(sys.stdin.read(), LOG_PATH)


if __name__ == '__main__':
  main()
