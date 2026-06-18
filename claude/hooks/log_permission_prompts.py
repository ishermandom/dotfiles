#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PermissionRequest hook: record every tool-use call that is about to prompt
# the user, then fall through so the prompt still appears. This event fires only
# after the allow list and PreToolUse have passed a call through to the user, so
# the log is a noise-free, authoritative list of exactly what prompts and why —
# the raw material for deciding which calls to allowlist or auto-allow.
#
# Log-only by design: it returns no decision, so it never changes which calls
# prompt. The output is one JSON object per line (JSONL) at LOG_PATH, greppable
# and machine-readable for later analysis.

import json
import sys
from collections.abc import Mapping
from datetime import UTC, datetime
from pathlib import Path

# Where prompt records accumulate, alongside the other ~/.claude logs.
LOG_PATH = Path('~/.claude/logs/permission-prompts.log').expanduser()


def record(payload: Mapping[str, object]) -> None:
  """Append one JSONL record describing the call that is about to prompt."""
  # tool_input is the full tool arguments (e.g. {"command": "..."} for Bash);
  # keep it whole so non-Bash prompts are captured as faithfully as Bash ones.
  entry = {
    'timestamp': datetime.now(UTC).isoformat(),
    'session_id': payload.get('session_id'),
    'permission_mode': payload.get('permission_mode'),
    'tool_name': payload.get('tool_name'),
    'tool_input': payload.get('tool_input'),
  }
  with LOG_PATH.open('a', encoding='utf-8') as log:
    log.write(json.dumps(entry, ensure_ascii=False) + '\n')


def main() -> None:
  """Read the hook payload from stdin and log it; emit no decision."""
  try:
    payload = json.load(sys.stdin)
  except json.JSONDecodeError:
    return  # Unparseable payload: fail open — never block the prompt flow.
  record(payload)


if __name__ == '__main__':
  main()
