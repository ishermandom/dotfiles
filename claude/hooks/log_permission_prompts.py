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
#
# The log self-rotates via the shared log_rotation helper: once the active file
# crosses MAX_ACTIVE_BYTES it is archived, and old archives are pruned to keep
# active + archives within TOTAL_BUDGET_BYTES. This bounds disk use without
# manual cleanup and keeps the active file small enough to read in full when
# analyzing prompts.

import json
import sys
from collections.abc import Mapping
from datetime import UTC, datetime
from pathlib import Path

import log_rotation

# Where prompt records accumulate, alongside the other ~/.claude logs.
LOG_PATH = Path('~/.claude/logs/permission-prompts.log').expanduser()

# Rotate the active log once it crosses this size. Sized so the whole log fits
# in a session's context in one read when analyzing prompts: at roughly four
# bytes per token, 64 KiB is ~16K tokens — a meaningful slice of history that
# still costs well under a tenth of the context window.
MAX_ACTIVE_BYTES = 64 * 1024

# Cap total disk for the active log plus all retained archives. Older archives
# are pruned to stay within this; the prompt history they hold has usually been
# distilled into allowlist rules well before it ages out.
TOTAL_BUDGET_BYTES = 10 * 1024 * 1024


def record(payload: Mapping[str, object], log_path: Path) -> None:
  """Append one JSONL record, then rotate the log if it grew too large."""
  # tool_input is the full tool arguments (e.g. {"command": "..."} for Bash);
  # keep it whole so non-Bash prompts are captured as faithfully as Bash ones.
  entry = {
    'timestamp': datetime.now(UTC).isoformat(),
    'session_id': payload.get('session_id'),
    'permission_mode': payload.get('permission_mode'),
    'tool_name': payload.get('tool_name'),
    'tool_input': payload.get('tool_input'),
  }
  with log_path.open('a', encoding='utf-8') as log:
    log.write(json.dumps(entry, ensure_ascii=False) + '\n')
  log_rotation.rotate_if_needed(log_path, MAX_ACTIVE_BYTES, TOTAL_BUDGET_BYTES)


def main() -> None:
  """Read the hook payload from stdin and log it; emit no decision."""
  try:
    payload = json.load(sys.stdin)
  except json.JSONDecodeError:
    return  # Unparseable payload: fail open — never block the prompt flow.
  record(payload, LOG_PATH)


if __name__ == '__main__':
  main()
