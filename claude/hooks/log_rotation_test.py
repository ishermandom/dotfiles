#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the shared log-rotation helper. Rotation is inherently
# filesystem-shaped — renaming the active log and pruning archives — so these
# tests drive it against a real temp directory rather than a stream.
# Run with the hooks directory on PYTHONPATH:
#   PYTHONPATH=~/.claude/hooks pytest ~/.claude/hooks/log_rotation_test.py

from collections.abc import Sequence
from datetime import date, timedelta
from pathlib import Path

import log_rotation


def _write(path: Path, byte_count: int) -> None:
  """Create `path` with exactly `byte_count` bytes of filler content."""
  path.write_bytes(b'x' * byte_count)


def _archives(log_path: Path) -> Sequence[Path]:
  """This log's archives under the archive dir, sorted oldest first."""
  archive_dir = log_path.parent / 'archive'
  pattern = f'{log_path.stem}-*{log_path.suffix}'
  return sorted(archive_dir.glob(pattern))


# --- rotation trigger ---


def test_log_under_the_cap_is_not_rotated(tmp_path: Path) -> None:
  """A log exactly at the cap stays in place, unarchived."""
  log_path = tmp_path / 'sample.log'
  _write(log_path, 100)  # at the 100-byte cap, not over it

  log_rotation.rotate_if_needed(
    log_path, max_active_bytes=100, total_budget_bytes=500
  )

  assert log_path.exists()  # left in place
  assert _archives(log_path) == []  # nothing archived


def test_log_over_the_cap_is_archived(tmp_path: Path) -> None:
  """A log past the cap is renamed into the archive subdir."""
  log_path = tmp_path / 'sample.log'
  _write(log_path, 101)  # one byte over the 100-byte cap

  log_rotation.rotate_if_needed(
    log_path, max_active_bytes=100, total_budget_bytes=500
  )

  assert not log_path.exists()  # renamed away; next append recreates it
  archives = _archives(log_path)
  assert len(archives) == 1
  assert archives[0].parent.name == 'archive'  # archived into the subdir


# --- archive naming ---


def test_same_day_rotations_do_not_collide(tmp_path: Path) -> None:
  """A second rotation on the same day takes an integer suffix."""
  log_path = tmp_path / 'sample.log'
  (tmp_path / 'archive').mkdir()

  # Two rotations on the same day must land on distinct paths.
  first = log_rotation._archive_path(log_path, '20260618')
  _write(first, 10)
  second = log_rotation._archive_path(log_path, '20260618')

  assert first.name == 'sample-20260618.log'
  assert second.name == 'sample-20260618-2.log'


# --- pruning ---


def test_pruning_keeps_archives_within_budget(tmp_path: Path) -> None:
  """Pruning drops the oldest archives until the budget holds."""
  log_path = tmp_path / 'sample.log'
  archive_dir = tmp_path / 'archive'
  archive_dir.mkdir()

  # Each archive is one full rotation's worth (100 bytes); the budget reserves
  # one such slot for the active log, so 500 // 100 - 1 = 4 archives fit.
  for offset in range(4 + 3):  # three more than the budget fits
    stamp = (date(2026, 1, 1) + timedelta(days=offset)).strftime('%Y%m%d')
    _write(archive_dir / f'sample-{stamp}.log', 100)

  log_rotation._prune_archives(
    log_path, max_active_bytes=100, total_budget_bytes=500
  )

  kept = _archives(log_path)
  assert len(kept) == 4  # oldest three deleted
  total_bytes = sum(path.stat().st_size for path in kept)
  assert total_bytes + 100 <= 500


def test_pruning_spares_other_sources_in_the_archive_dir(
  tmp_path: Path,
) -> None:
  """Pruning ignores logs from other sources in the archive dir."""
  log_path = tmp_path / 'sample.log'
  archive_dir = tmp_path / 'archive'
  archive_dir.mkdir()

  # A foreign log far larger than the budget must not be counted or deleted.
  foreign = archive_dir / 'other-20260618.log'
  _write(foreign, 5000)
  _write(archive_dir / 'sample-20260618.log', 10)

  log_rotation._prune_archives(
    log_path, max_active_bytes=100, total_budget_bytes=500
  )

  assert foreign.exists()  # untouched despite blowing the budget
  assert len(_archives(log_path)) == 1  # this log's archive survives
