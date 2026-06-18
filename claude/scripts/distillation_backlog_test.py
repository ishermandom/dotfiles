#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the distillation-backlog script, exercised through its
# public entry point — main() reading the session log from a stream and
# printing one backlog line. Run via the project suite (./run_tests.sh) or:
#   PYTHONPATH=claude/scripts pytest claude/scripts/distillation_backlog_test.py

import io

from distillation_backlog import main


def _backlog_line(*headings: str) -> str:
  """The line main() prints for a log built from the given heading lines."""
  log_text = '\n'.join(headings) + '\n' if headings else ''
  stdout = io.StringIO()
  main(io.StringIO(log_text), stdout)
  return stdout.getvalue().rstrip('\n')


# --- counting since the last distillation marker ---


def test_counts_every_entry_when_the_log_was_never_distilled() -> None:
  line = _backlog_line(
    '## 2026-06-01 · crosswords · coding',
    '## 2026-06-02 · dotfiles · refactor',
  )

  assert line == '2 reflection entries in the log; no distillation marker yet.'


def test_counts_only_entries_after_the_last_marker() -> None:
  line = _backlog_line(
    '## 2026-06-01 · crosswords · coding',
    '## 2026-06-02 — distillation',
    '## 2026-06-03 · dotfiles · refactor',
    '## 2026-06-04 · dotfiles · coding',
  )

  # The entry before the marker is excluded; only the two after it count.
  assert line == '2 reflection entries since the last distillation marker.'


def test_only_the_last_of_several_markers_bounds_the_count() -> None:
  line = _backlog_line(
    '## 2026-06-01 · dotfiles · coding',
    '## 2026-06-02 — distillation',
    '## 2026-06-03 · dotfiles · refactor',
    '## 2026-06-04 — distillation',
    '## 2026-06-05 · dotfiles · coding',
  )

  assert line == '1 reflection entry since the last distillation marker.'


def test_backlog_is_zero_immediately_after_a_distillation() -> None:
  line = _backlog_line(
    '## 2026-06-01 · dotfiles · coding',
    '## 2026-06-02 — distillation',
  )

  assert line == '0 reflection entries since the last distillation marker.'


def test_empty_log_reports_a_zero_backlog_and_no_marker() -> None:
  assert _backlog_line() == (
    '0 reflection entries in the log; no distillation marker yet.'
  )


# --- distinguishing entry kinds ---


def test_stats_only_counted_apart_from_reflection() -> None:
  line = _backlog_line(
    '## 2026-06-01 · dotfiles · coding',
    '## 2026-06-02 · crosswords · stats-only',
    '## 2026-06-03 · crosswords · stats-only',
  )

  # Reflection count leads (singular here); stats-only is called out so it
  # doesn't inflate the figure the distill decision keys on.
  assert line == (
    '1 reflection entry (plus 2 stats-only) in the log; '
    'no distillation marker yet.'
  )


def test_em_dash_date_separator_is_not_mistaken_for_a_marker() -> None:
  # Some entries put an em-dash between date and project; only a heading
  # ending in 'distillation' is a marker, and these carry reflection content.
  line = _backlog_line(
    '## 2026-06-01 — crosswords (coding)',
    '## 2026-06-02 — crosswords (housekeeping)',
  )

  assert line == '2 reflection entries in the log; no distillation marker yet.'


def test_level_three_subsection_headings_are_not_counted() -> None:
  line = _backlog_line(
    '## 2026-06-01 · dotfiles · coding',
    '### Inefficiency',
    '- ran a redundant command',
    '### Rules',
    '## 2026-06-02 · dotfiles · refactor',
  )

  # The two `### ` subsections are not entries; only the two `## ` lines are.
  assert line == '2 reflection entries in the log; no distillation marker yet.'
