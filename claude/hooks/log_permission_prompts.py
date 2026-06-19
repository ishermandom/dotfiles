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
# The log self-rotates: once the active file crosses MAX_ACTIVE_BYTES it is
# archived under a timestamped name in an `archive/` subdir, and the oldest
# archives are pruned to keep the active file plus all archives within
# TOTAL_BUDGET_BYTES. This bounds disk use without manual cleanup and keeps the
# active file small enough to read in full when analyzing prompts.

import json
import sys
from collections.abc import Mapping
from datetime import UTC, datetime
from pathlib import Path

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
  rotate_if_needed(log_path)


def rotate_if_needed(log_path: Path) -> None:
  """Archive the active log once it exceeds the rotation cap, then prune.

  A no-op until the log crosses MAX_ACTIVE_BYTES. The rename leaves no active
  file behind; the next append recreates it.
  """
  try:
    size = log_path.stat().st_size
  except FileNotFoundError:
    return  # Nothing logged yet.
  if size <= MAX_ACTIVE_BYTES:
    return

  _archive_dir(log_path).mkdir(parents=True, exist_ok=True)
  archive = _archive_path(log_path, datetime.now(UTC).strftime('%Y%m%d'))
  try:
    log_path.rename(archive)
  except FileNotFoundError:
    return  # A concurrent session rotated the log first.
  _prune_archives(log_path)


def _archive_dir(log_path: Path) -> Path:
  """The subdirectory holding rotated archives of `log_path`."""
  return log_path.parent / 'archive'


def _archive_path(log_path: Path, date_text: str) -> Path:
  """Pick a collision-free archive path for `log_path` dated `date_text`.

  Names archives `<stem>-<date><suffix>` so they sort by day and stay distinct
  from the active log. Multiple rotations within one day — rare, since each must
  fill the active log to its cap — take an integer suffix (`-2`, `-3`, …) so a
  busy day never overwrites an earlier archive; their order among one day's
  archives is immaterial to pruning, which works at day resolution.
  """
  directory = _archive_dir(log_path)
  stem, suffix = log_path.stem, log_path.suffix
  candidate = directory / f'{stem}-{date_text}{suffix}'
  collision_index = 2
  while candidate.exists():
    candidate = directory / f'{stem}-{date_text}-{collision_index}{suffix}'
    collision_index += 1
  return candidate


def _prune_archives(log_path: Path) -> None:
  """Delete the oldest archives so active + archives stay within the budget.

  Reserves room for the active log to refill to its rotation cap, then keeps
  the newest archives whose cumulative size fits the remaining budget and
  deletes the rest. The pattern matches only this script's archives, so other
  sources' logs sharing the archive dir are neither counted nor pruned.
  """
  pattern = f'{log_path.stem}-*{log_path.suffix}'
  # Sort newest day first so the budget walk keeps recent archives over old.
  archives = sorted(_archive_dir(log_path).glob(pattern), reverse=True)
  budget = TOTAL_BUDGET_BYTES - MAX_ACTIVE_BYTES
  cumulative = 0
  for archive in archives:
    try:
      cumulative += archive.stat().st_size
    except FileNotFoundError:
      continue  # A concurrent prune already removed it.
    if cumulative > budget:
      archive.unlink(missing_ok=True)


def main() -> None:
  """Read the hook payload from stdin and log it; emit no decision."""
  try:
    payload = json.load(sys.stdin)
  except json.JSONDecodeError:
    return  # Unparseable payload: fail open — never block the prompt flow.
  record(payload, LOG_PATH)


if __name__ == '__main__':
  main()
