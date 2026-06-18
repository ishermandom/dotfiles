#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
"""Report how many session entries await distillation.

The wrap-session skill suggests running the distill skill once enough
session entries have accumulated since the last distillation. It calls
this script for that count rather than grepping the log inline: a bare
grep invites a `2>/dev/null` redirect, and any redirect to a path outside
the workspace trips Claude Code's write-scope gate and forces a prompt.
This script does its reads internally and prints a single line, so the
allowlisted Bash command carries no redirect.

The session log (`~/.claude/logs/sessions.md`) is a flat list of level-2
Markdown headings: one per session entry, plus a `## <date> — distillation`
heading each time the distill skill runs.
"""

import io
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO

DEFAULT_LOG_PATH = Path.home() / '.claude' / 'logs' / 'sessions.md'

# Session entries and distillation markers are both level-2 headings; their
# subsections (`### Inefficiency`, etc.) are level-3 and must not be counted.
ENTRY_HEADING_PREFIX = '## '


@dataclass(frozen=True)
class DistillationBacklog:
  """Session entries accumulated since the log's last distillation.

  Reflection entries and stats-only entries are counted apart: only the
  former carry the content distillation consumes, so the stats-only count
  must not pad the figure the distill decision keys on.
  """

  reflection_entry_count: int
  stats_only_count: int
  last_marker: str | None


def _is_distillation_marker(heading: str) -> bool:
  """Whether a level-2 heading is a distillation marker.

  The distill skill writes `## <date> — distillation`; ordinary entries
  end in a session type (`coding`, `refactor`, `stats-only`, …). Matching
  the trailing word, not the dash, avoids misreading entries that use an
  em-dash as their date/project separator (`## <date> — <project> (type)`).
  """
  return heading.rstrip().lower().endswith('distillation')


def _is_stats_only_entry(heading: str) -> bool:
  """Whether a level-2 heading is a stats-only entry.

  The SessionEnd hook writes `## <date> · <project> · stats-only` for a
  session that never ran wrap-session: it carries token counts but none of
  the Inefficiency/Corrections/Rules content distillation feeds on.
  """
  return heading.rstrip().lower().endswith('stats-only')


def _distillation_backlog(log_text: str) -> DistillationBacklog:
  """Count entries after the log's last distillation marker, split by kind.

  With no marker — the log has never been distilled — every entry counts.
  Reflection and stats-only entries are tallied separately so the caller
  can weigh distill input by the entries that actually carry reflection.
  """
  headings = [
    line
    for line in log_text.splitlines()
    if line.startswith(ENTRY_HEADING_PREFIX)
  ]
  marker_positions = [
    index
    for index, heading in enumerate(headings)
    if _is_distillation_marker(heading)
  ]
  # No marker yet: -1 makes the slice below start at the first heading, so
  # every entry counts.
  last_position = marker_positions[-1] if marker_positions else -1
  entries = headings[last_position + 1 :]

  stats_only_count = sum(
    1 for heading in entries if _is_stats_only_entry(heading)
  )
  return DistillationBacklog(
    reflection_entry_count=len(entries) - stats_only_count,
    stats_only_count=stats_only_count,
    last_marker=headings[last_position] if marker_positions else None,
  )


def _backlog_summary(backlog: DistillationBacklog) -> str:
  """A one-line backlog report for the wrap-session reflection step.

  Leads with the reflection-entry count — what distillation consumes — and
  notes stats-only entries separately so they don't inflate that figure.
  """
  reflection_count = backlog.reflection_entry_count
  noun = 'entry' if reflection_count == 1 else 'entries'
  stats_note = (
    f' (plus {backlog.stats_only_count} stats-only)'
    if backlog.stats_only_count
    else ''
  )
  if not backlog.last_marker:
    return (
      f'{reflection_count} reflection {noun}{stats_note} in the log; '
      f'no distillation marker yet.'
    )
  return (
    f'{reflection_count} reflection {noun}{stats_note} '
    f'since the last distillation marker.'
  )


def main(log_stream: TextIO, stdout: TextIO = sys.stdout) -> None:
  """Read the session log from `log_stream` and print its backlog summary."""
  backlog = _distillation_backlog(log_stream.read())
  print(_backlog_summary(backlog), file=stdout)


if __name__ == '__main__':
  # The log may not exist yet on a fresh setup; treat that as empty.
  log_text = DEFAULT_LOG_PATH.read_text() if DEFAULT_LOG_PATH.exists() else ''
  main(io.StringIO(log_text))
