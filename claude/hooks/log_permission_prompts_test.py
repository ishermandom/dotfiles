#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the permission-prompt logger's self-rotation. Rotation is
# inherently filesystem-shaped — renaming the active log and pruning archives —
# so these tests drive it against a real temp directory rather than a stream.
# Run with the hooks directory on PYTHONPATH:
#   PYTHONPATH=~/.claude/hooks pytest ~/.claude/hooks/log_permission_prompts_test.py

from collections.abc import Sequence
from datetime import date, timedelta
from pathlib import Path

import log_permission_prompts as logger


def _write(path: Path, byte_count: int) -> None:
  """Create `path` with exactly `byte_count` bytes of filler content."""
  path.write_bytes(b'x' * byte_count)


def _archives(log_path: Path) -> Sequence[Path]:
  """This script's archives under the archive dir, sorted oldest first."""
  archive_dir = log_path.parent / 'archive'
  pattern = f'{log_path.stem}-*{log_path.suffix}'
  return sorted(archive_dir.glob(pattern))


# --- rotation trigger ---


def test_log_under_the_cap_is_not_rotated(tmp_path: Path) -> None:
  """A log exactly at the cap stays in place, unarchived."""
  log_path = tmp_path / 'permission-prompts.log'
  _write(log_path, logger.MAX_ACTIVE_BYTES)  # at the cap, not over it

  logger.rotate_if_needed(log_path)

  assert log_path.exists()  # left in place
  assert _archives(log_path) == []  # nothing archived


def test_log_over_the_cap_is_archived(tmp_path: Path) -> None:
  """A log past the cap is renamed into the archive subdir."""
  log_path = tmp_path / 'permission-prompts.log'
  _write(log_path, logger.MAX_ACTIVE_BYTES + 1)

  logger.rotate_if_needed(log_path)

  assert not log_path.exists()  # renamed away; next append recreates it
  archives = _archives(log_path)
  assert len(archives) == 1
  assert archives[0].parent.name == 'archive'  # archived into the subdir


# --- archive naming ---


def test_same_day_rotations_do_not_collide(tmp_path: Path) -> None:
  """A second rotation on the same day takes an integer suffix."""
  log_path = tmp_path / 'permission-prompts.log'
  (tmp_path / 'archive').mkdir()

  # Two rotations on the same day must land on distinct paths.
  first = logger._archive_path(log_path, '20260618')
  _write(first, 10)
  second = logger._archive_path(log_path, '20260618')

  assert first.name == 'permission-prompts-20260618.log'
  assert second.name == 'permission-prompts-20260618-2.log'


# --- pruning ---


def test_pruning_keeps_archives_within_budget(tmp_path: Path) -> None:
  """Pruning drops the oldest archives until the budget holds."""
  log_path = tmp_path / 'permission-prompts.log'
  archive_dir = tmp_path / 'archive'
  archive_dir.mkdir()

  # Each archive is one full rotation's worth; the budget reserves one such
  # slot for the active log, so floor(TOTAL / MAX) - 1 archives fit.
  archive_size = logger.MAX_ACTIVE_BYTES
  archives_that_fit = logger.TOTAL_BUDGET_BYTES // archive_size - 1
  for offset in range(archives_that_fit + 3):  # three more than the budget fits
    stamp = (date(2026, 1, 1) + timedelta(days=offset)).strftime('%Y%m%d')
    _write(archive_dir / f'permission-prompts-{stamp}.log', archive_size)

  logger._prune_archives(log_path)

  kept = _archives(log_path)
  assert len(kept) == archives_that_fit  # oldest three deleted
  total_bytes = sum(path.stat().st_size for path in kept)
  assert total_bytes + logger.MAX_ACTIVE_BYTES <= logger.TOTAL_BUDGET_BYTES


def test_pruning_spares_other_sources_in_the_archive_dir(
  tmp_path: Path,
) -> None:
  """Pruning ignores logs from other sources in the archive dir."""
  log_path = tmp_path / 'permission-prompts.log'
  archive_dir = tmp_path / 'archive'
  archive_dir.mkdir()

  # A foreign log far larger than the budget must not be counted or deleted.
  foreign = archive_dir / 'sessions-20260618T120000Z.log'
  _write(foreign, logger.TOTAL_BUDGET_BYTES * 2)
  _write(archive_dir / 'permission-prompts-20260618T120000Z.log', 10)

  logger._prune_archives(log_path)

  assert foreign.exists()  # untouched despite blowing the budget
  assert len(_archives(log_path)) == 1  # this script's archive survives
