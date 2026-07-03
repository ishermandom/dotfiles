#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
"""Record per-session token counts in the global session log.

As a SessionEnd hook (JSON payload on stdin), sums the four API usage counters
across the session's transcript and subagent transcripts, then writes a
`tokens:` line into the session log: into the entry whose session-id marker
matches (the wrap-session skill stamps the marker), or as a new counts-only
"stats-only" entry when no marker exists.

With `--print`, reports the live session's marker line and provisional counts
without writing — reflection input for the wrap-session skill; the SessionEnd
hook writes the final, complete line.
"""

import argparse
import json
import os
import re
import sys
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

import log_rotation

DEFAULT_LOG_PATH = Path.home() / '.claude' / 'logs' / 'sessions.md'
DIAGNOSTIC_LOG_PATH = Path.home() / '.claude' / 'logs' / 'session-tokens.log'

# Bound the diagnostic log's disk use; it's a small error trace, so a tight
# budget suffices.
DIAGNOSTIC_LOG_MAX_ACTIVE_BYTES = 64 * 1024
DIAGNOSTIC_LOG_TOTAL_BUDGET_BYTES = 256 * 1024

# sessions.md is a curated record, so it isn't auto-rotated — rotating would
# fragment its searchable history. Warn once it grows past this instead, so it
# can be distilled or rotated deliberately.
SESSIONS_LOG_WARN_BYTES = 512 * 1024

# Counter fields summed into the log, plus the non-counter fields current
# transcript records carry. A field outside this set means the usage schema
# changed and the counters may be silently wrong.
EXPECTED_USAGE_FIELD_NAMES = frozenset(
  {
    'input_tokens',
    'output_tokens',
    'cache_creation_input_tokens',
    'cache_read_input_tokens',
    'cache_creation',
    'inference_geo',
    'iterations',
    'output_tokens_details',
    'server_tool_use',
    'service_tier',
    'speed',
  }
)


def log_diagnostic(message: str) -> None:
  """Report a problem to stderr and the diagnostic log file.

  stderr alone would vanish: SessionEnd hook output is shown only in debug mode,
  and the session is already over when this hook runs.
  """
  print(f'session-tokens: {message}', file=sys.stderr)
  DIAGNOSTIC_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
  timestamp = datetime.now().isoformat(timespec='seconds')
  with DIAGNOSTIC_LOG_PATH.open('a') as log_file:
    log_file.write(f'{timestamp} {message}\n')
  log_rotation.rotate_if_needed(
    DIAGNOSTIC_LOG_PATH,
    DIAGNOSTIC_LOG_MAX_ACTIVE_BYTES,
    DIAGNOSTIC_LOG_TOTAL_BUDGET_BYTES,
  )


@dataclass(frozen=True)
class UsageTotals:
  """Summed API usage counters for one session's transcripts."""

  input_tokens: int
  output_tokens: int
  cache_creation_input_tokens: int
  cache_read_input_tokens: int


def _usage_of(record: object) -> Mapping[str, object] | None:
  """The usage mapping on one transcript record; None when absent."""
  if not isinstance(record, Mapping):
    return None
  message = record.get('message')
  if not isinstance(message, Mapping):
    return None
  usage = message.get('usage')
  return usage if isinstance(usage, Mapping) else None


def summed_usage(transcript_paths: Iterable[Path]) -> UsageTotals:
  """Sum the usage counters across all records in the transcripts."""
  totals = {
    'input_tokens': 0,
    'output_tokens': 0,
    'cache_creation_input_tokens': 0,
    'cache_read_input_tokens': 0,
  }
  malformed_line_count = 0
  missing_paths: list[Path] = []
  # Each distinct schema oddity is logged once after the sweep, not per record —
  # a drifted schema would otherwise flood the diagnostic log.
  oddities: set[str] = set()
  for path in transcript_paths:
    try:
      transcript_text = path.read_text()
    except FileNotFoundError:
      # SessionEnd can fire with a transcript that was never written (e.g. a
      # session cleared before its first write); sum what exists rather than
      # losing the whole session from the log.
      missing_paths.append(path)
      continue
    for line in transcript_text.splitlines():
      try:
        record: object = json.loads(line)
      except json.JSONDecodeError:
        # A crash mid-write can truncate the final line; count and continue
        # rather than losing the whole transcript's totals.
        malformed_line_count += 1
        continue
      usage = _usage_of(record)
      if usage is None:
        continue
      for name in usage.keys() - EXPECTED_USAGE_FIELD_NAMES:
        oddities.add(f'unexpected usage field: {name}')
      for name in totals:
        value = usage.get(name)
        if isinstance(value, int):
          totals[name] += value
        elif value is not None:
          oddities.add(f'non-integer counter {name}: {value!r}')
  if malformed_line_count:
    log_diagnostic(
      f'skipped {malformed_line_count} malformed transcript line(s)'
    )
  if missing_paths:
    log_diagnostic(
      f'{len(missing_paths)} transcript file(s) missing, summed the rest: '
      f'{", ".join(path.name for path in missing_paths)}'
    )
  for oddity in sorted(oddities):
    log_diagnostic(oddity)
  return UsageTotals(
    input_tokens=totals['input_tokens'],
    output_tokens=totals['output_tokens'],
    cache_creation_input_tokens=totals['cache_creation_input_tokens'],
    cache_read_input_tokens=totals['cache_read_input_tokens'],
  )


def session_transcript_paths(transcript_path: Path) -> Sequence[Path]:
  """The main transcript plus the session's subagent transcripts.

  Subagent transcripts live in a `<session-id>/subagents/` directory alongside
  the main `<session-id>.jsonl` file.
  """
  subagent_directory = (
    transcript_path.parent / transcript_path.stem / 'subagents'
  )
  return [transcript_path, *sorted(subagent_directory.glob('*.jsonl'))]


def formatted_count(count: int) -> str:
  """A compact form: 873 → '873', 51049 → '51.0k', 10703404 → '10.7M'."""
  for threshold, suffix in ((1_000_000, 'M'), (1_000, 'k')):
    if count >= threshold:
      scaled = count / threshold
      digits = 0 if scaled >= 100 else 1
      return f'{scaled:.{digits}f}{suffix}'
  return str(count)


def tokens_line(totals: UsageTotals) -> str:
  """The log line summarizing one session's token counts."""
  return (
    f'tokens: input {formatted_count(totals.input_tokens)}'
    f' · output {formatted_count(totals.output_tokens)}'
    f' · cache-write {formatted_count(totals.cache_creation_input_tokens)}'
    f' · cache-read {formatted_count(totals.cache_read_input_tokens)}'
  )


def marker_line(session_id: str) -> str:
  """The marker comment that ties a log entry to its session."""
  return f'<!-- session: {session_id} -->'


def updated_log_text(
  log_text: str, session_id: str, new_line: str
) -> str | None:
  """log_text with new_line inserted after the session's marker.

  Returns None when the marker is absent. When several entries carry the marker
  (wrap-session ran more than once), the last one wins. Returns the text
  unchanged when a tokens line already follows the marker, so a duplicate hook
  firing is a no-op.
  """
  marker = marker_line(session_id)
  lines = log_text.splitlines()
  if marker not in lines:
    return None
  index = len(lines) - 1 - lines[::-1].index(marker)
  follower = lines[index + 1] if index + 1 < len(lines) else ''
  if follower.startswith('tokens:'):
    return log_text
  lines.insert(index + 1, new_line)
  return '\n'.join(lines) + '\n'


def stats_only_entry(
  project: str, session_id: str, new_line: str, entry_date: str
) -> str:
  """A counts-only log entry for a session with no wrap entry."""
  return (
    f'\n## {entry_date} · {project} · stats-only\n'
    f'\n'
    f'{marker_line(session_id)}\n'
    f'{new_line}\n'
  )


def write_log(log_path: Path, text: str) -> None:
  """Replace the log atomically so a failure can't truncate it.

  The temporary file is pid-unique so two sessions ending together never write
  through the same intermediate path.
  """
  log_path.parent.mkdir(parents=True, exist_ok=True)
  temporary_path = log_path.parent / f'{log_path.name}.{os.getpid()}.tmp'
  temporary_path.write_text(text)
  temporary_path.replace(log_path)


def _stat_signature(path: Path) -> tuple[int, int] | None:
  """A cheap change detector for the log: (size, mtime_ns); None if absent."""
  try:
    file_stat = path.stat()
  except FileNotFoundError:
    return None
  return (file_stat.st_size, file_stat.st_mtime_ns)


def record_session_end(payload: Mapping[str, object], log_path: Path) -> None:
  """Count the ended session's tokens and record them in the log."""
  transcript_value = payload.get('transcript_path')
  if not isinstance(transcript_value, str):
    raise ValueError(f'payload has no transcript_path: {dict(payload)}')
  transcript_path = Path(transcript_value)
  session_value = payload.get('session_id')
  session_id = (
    session_value if isinstance(session_value, str) else transcript_path.stem
  )

  totals = summed_usage(session_transcript_paths(transcript_path))
  new_line = tokens_line(totals)
  cwd_value = payload.get('cwd')
  project = Path(cwd_value).name if isinstance(cwd_value, str) else 'unknown'

  # Optimistic concurrency, deliberately lock-free: when another writer (a
  # concurrent SessionEnd, a wrap-time append) lands between our read and our
  # replace, recompute from a fresh read. Stateless, so nothing can wedge; after
  # the retries, last-writer-wins matches the old behavior.
  for is_final_attempt in (False, False, True):
    signature_before = _stat_signature(log_path)
    log_text = log_path.read_text() if log_path.exists() else ''
    updated_text = updated_log_text(log_text, session_id, new_line)
    if updated_text is None:
      entry = stats_only_entry(
        project, session_id, new_line, date.today().isoformat()
      )
      updated_text = log_text + entry
    if _stat_signature(log_path) == signature_before or is_final_attempt:
      if is_final_attempt and _stat_signature(log_path) != signature_before:
        log_diagnostic('concurrent sessions.md writers; last writer wins')
      write_log(log_path, updated_text)
      break

  # sessions.md isn't rotated; flag it for deliberate cleanup once it's large.
  size = log_path.stat().st_size
  if size > SESSIONS_LOG_WARN_BYTES:
    log_diagnostic(
      f'{log_path.name} has grown to {size} bytes, past the '
      f'{SESSIONS_LOG_WARN_BYTES}-byte warn threshold; consider distilling or '
      f'rotating it'
    )


# Transcripts modified this close together mean concurrently live sessions,
# where a newest-mtime guess may pick another session's transcript.
AMBIGUITY_WINDOW_SECONDS = 600


def live_transcript_path(
  cwd: Path, session_id: str | None
) -> tuple[Path, str | None]:
  """The live session's transcript, plus a warning when the pick is a guess.

  A session id resolves the transcript exactly. Without one, fall back to the
  newest-mtime transcript in cwd's project directory — right for a lone session,
  a guess under concurrency, hence the returned warning.
  """
  slug = re.sub(r'[^A-Za-z0-9-]', '-', str(cwd))
  project_directory = Path.home() / '.claude' / 'projects' / slug
  if session_id:
    exact_path = project_directory / f'{session_id}.jsonl'
    if exact_path.exists():
      return exact_path, None
  transcript_paths = sorted(
    project_directory.glob('*.jsonl'),
    key=lambda path: path.stat().st_mtime,
    reverse=True,
  )
  if not transcript_paths:
    raise FileNotFoundError(f'no transcripts under {project_directory}')
  newest_path = transcript_paths[0]
  if session_id:
    return newest_path, (
      f'--session-id {session_id} has no transcript; fell back to the '
      f'newest, {newest_path.stem}'
    )
  newest_mtime = newest_path.stat().st_mtime
  concurrent_count = sum(
    1
    for path in transcript_paths
    if newest_mtime - path.stat().st_mtime < AMBIGUITY_WINDOW_SECONDS
  )
  if concurrent_count > 1:
    return newest_path, (
      f'{concurrent_count} transcripts changed within '
      f'{AMBIGUITY_WINDOW_SECONDS // 60} minutes — this marker may belong to '
      f'another session; pass --session-id'
    )
  return newest_path, None


def print_live_counts(session_id: str | None) -> None:
  """Print the live session's marker line and provisional tokens line."""
  transcript_path, warning = live_transcript_path(Path.cwd(), session_id)
  totals = summed_usage(session_transcript_paths(transcript_path))
  print(marker_line(transcript_path.stem))
  print(tokens_line(totals))
  if warning:
    print(f'warning: {warning}')


def main() -> int:
  """Dispatch between hook mode (stdin payload) and `--print`."""
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    '--print',
    dest='print_only',
    action='store_true',
    help='print the live session marker and counts; write nothing',
  )
  parser.add_argument(
    '--session-id',
    help='the live session id; --print then resolves its transcript exactly '
    'instead of guessing by newest mtime',
  )
  parser.add_argument(
    '--log',
    type=Path,
    default=DEFAULT_LOG_PATH,
    help='session log to update (for tests)',
  )
  arguments = parser.parse_args()

  try:
    if arguments.print_only:
      print_live_counts(arguments.session_id)
    else:
      payload: object = json.loads(sys.stdin.read())
      if not isinstance(payload, Mapping):
        raise ValueError(f'hook payload is not a JSON object: {payload!r}')
      record_session_end(payload, arguments.log)
  except (OSError, ValueError, json.JSONDecodeError) as error:
    log_diagnostic(str(error))
    return 1
  return 0


if __name__ == '__main__':
  sys.exit(main())
