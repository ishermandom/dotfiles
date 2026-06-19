# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Shared size-triggered rotation for the append-only logs under ~/.claude/logs.
# A producing hook appends to its log, then calls rotate_if_needed to bound disk
# use: once the active file crosses its cap it is renamed into an `archive/`
# subdir under a date-stamped name, and the oldest archives are pruned to keep
# the active file plus all archives within a per-source budget.
#
# Each source passes its own caps, so a high-value log (e.g. permission prompts,
# the raw material for allowlist distillation) can retain far more history than
# a disposable diagnostic. Archive names are namespaced by the log's stem, so
# several sources can share one archive dir without counting or pruning each
# other's files.

from datetime import UTC, datetime
from pathlib import Path


def rotate_if_needed(
  log_path: Path, max_active_bytes: int, total_budget_bytes: int
) -> None:
  """Archive the active log once it exceeds its cap, then prune to budget.

  A no-op until the log crosses max_active_bytes. The rename leaves no active
  file behind; the next append recreates it.
  """
  try:
    size = log_path.stat().st_size
  except FileNotFoundError:
    return  # Nothing logged yet.
  if size <= max_active_bytes:
    return

  _archive_dir(log_path).mkdir(parents=True, exist_ok=True)
  archive = _archive_path(log_path, datetime.now(UTC).strftime('%Y%m%d'))
  try:
    log_path.rename(archive)
  except FileNotFoundError:
    return  # A concurrent session rotated the log first.
  _prune_archives(log_path, max_active_bytes, total_budget_bytes)


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


def _prune_archives(
  log_path: Path, max_active_bytes: int, total_budget_bytes: int
) -> None:
  """Delete the oldest archives so active + archives stay within the budget.

  Reserves room for the active log to refill to its cap, then keeps the newest
  archives whose cumulative size fits the remaining budget and deletes the rest.
  The pattern matches only this log's archives, so other sources' logs sharing
  the archive dir are neither counted nor pruned.
  """
  pattern = f'{log_path.stem}-*{log_path.suffix}'
  # Sort newest day first so the budget walk keeps recent archives over old.
  archives = sorted(_archive_dir(log_path).glob(pattern), reverse=True)
  budget = total_budget_bytes - max_active_bytes
  cumulative = 0
  for archive in archives:
    try:
      cumulative += archive.stat().st_size
    except FileNotFoundError:
      continue  # A concurrent prune already removed it.
    if cumulative > budget:
      archive.unlink(missing_ok=True)
