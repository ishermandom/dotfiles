# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for session_tokens' summing, formatting, and log-editing logic. The
# remaining I/O paths — opening transcript files, hook dispatch — are exercised
# manually; see the module's docstring for the hook contract.

import io
import json
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest
from session_tokens import (
  UsageTotals,
  formatted_count,
  session_transcript_paths,
  stats_only_entry,
  tokens_line,
  updated_log_text,
  usage_summary,
)


def _make_transcript(records: Sequence[object]) -> io.StringIO:
  """A transcript stream carrying one JSON-serialized record per line."""
  return io.StringIO(''.join(f'{json.dumps(record)}\n' for record in records))


def _make_raw_transcript(lines: Sequence[str]) -> io.StringIO:
  """A transcript stream from literal lines, for malformed-input tests."""
  return io.StringIO(''.join(f'{line}\n' for line in lines))


def _make_usage_record(usage: Mapping[str, object]) -> Mapping[str, object]:
  """A transcript record wrapping one usage mapping."""
  return {'message': {'usage': usage}}


# --- formatted_count ---


@pytest.mark.parametrize(
  ('count', 'expected'),
  [
    (873, '873'),
    (1000, '1.0k'),
    (51049, '51.0k'),
    (100000, '100k'),
    (2500000, '2.5M'),
    (10703404, '10.7M'),
  ],
)
def test_counts_format_compactly_at_each_scale(
  count: int, expected: str
) -> None:
  """Counts render bare below 1k, then scale to k/M with 100+ dropping the
  decimal.
  """
  assert formatted_count(count) == expected


# --- tokens_line ---


def test_tokens_line_names_all_four_counters() -> None:
  """The log line carries all four counters in a fixed, labeled order."""
  totals = UsageTotals(
    input_tokens=873,
    output_tokens=51049,
    cache_creation_input_tokens=10703404,
    cache_read_input_tokens=999,
  )

  line = tokens_line(totals)

  assert line == (
    'tokens: input 873 · output 51.0k · cache-write 10.7M · cache-read 999'
  )


# --- updated_log_text ---


def test_tokens_line_is_inserted_after_the_matching_marker() -> None:
  """The new line lands directly under the entry's session marker."""
  log = '## entry\n\n<!-- session: abc -->\nbody\n'

  updated = updated_log_text(log, 'abc', 'tokens: input 1')

  assert updated == '## entry\n\n<!-- session: abc -->\ntokens: input 1\nbody\n'


def test_missing_marker_returns_none() -> None:
  """No matching marker means the caller must append a stats-only entry."""
  log = '## entry\n\n<!-- session: other -->\nbody\n'

  assert updated_log_text(log, 'abc', 'tokens: input 1') is None


def test_last_marker_wins_when_wrap_session_ran_twice() -> None:
  """With duplicate markers, the insertion targets the newest entry."""
  log = (
    '## first\n\n<!-- session: abc -->\nolder body\n\n'
    '## second\n\n<!-- session: abc -->\nnewer body\n'
  )

  updated = updated_log_text(log, 'abc', 'tokens: input 1')

  assert updated == (
    '## first\n\n<!-- session: abc -->\nolder body\n\n'
    '## second\n\n<!-- session: abc -->\ntokens: input 1\nnewer body\n'
  )


def test_existing_tokens_line_makes_a_duplicate_firing_a_no_op() -> None:
  """A tokens line already under the marker is kept, not doubled."""
  log = '## entry\n\n<!-- session: abc -->\ntokens: input 1\nbody\n'

  assert updated_log_text(log, 'abc', 'tokens: input 2') == log


# --- stats_only_entry ---


def test_stats_only_entry_carries_heading_marker_and_counts() -> None:
  """A session with no wrap entry gets a minimal, marker-matched entry."""
  entry = stats_only_entry('dotfiles', 'abc', 'tokens: input 1', '2026-07-02')

  assert entry == (
    '\n## 2026-07-02 · dotfiles · stats-only\n'
    '\n'
    '<!-- session: abc -->\n'
    'tokens: input 1\n'
  )


# --- usage_summary ---


def test_all_four_counters_sum_across_records() -> None:
  """Every counter accumulates over the transcript's usage records."""
  transcript = _make_transcript(
    [
      _make_usage_record(
        {
          'input_tokens': 10,
          'output_tokens': 1,
          'cache_creation_input_tokens': 100,
          'cache_read_input_tokens': 1000,
        }
      ),
      _make_usage_record(
        {
          'input_tokens': 5,
          'output_tokens': 2,
          'cache_creation_input_tokens': 200,
          'cache_read_input_tokens': 3000,
        }
      ),
    ]
  )

  summary = usage_summary([transcript])

  assert summary.totals == UsageTotals(
    input_tokens=15,
    output_tokens=3,
    cache_creation_input_tokens=300,
    cache_read_input_tokens=4000,
  )
  assert summary.anomalies == ()


def test_counters_sum_across_several_transcripts() -> None:
  """A session's subagent transcripts fold into the same totals."""
  main_transcript = _make_transcript([_make_usage_record({'input_tokens': 10})])
  subagent_transcript = _make_transcript(
    [_make_usage_record({'input_tokens': 5})]
  )

  summary = usage_summary([main_transcript, subagent_transcript])

  assert summary.totals.input_tokens == 15


@pytest.mark.parametrize(
  'record',
  [
    {'type': 'user', 'message': {'content': 'hello'}},
    {'message': 'not a mapping'},
    {'message': {'usage': 'not a mapping'}},
    ['not a mapping at all'],
    'a bare string',
  ],
)
def test_records_without_a_usage_mapping_are_ignored(record: object) -> None:
  """Only a record carrying `message.usage` contributes to the totals."""
  transcript = _make_transcript([record])

  summary = usage_summary([transcript])

  assert summary.totals == UsageTotals(
    input_tokens=0,
    output_tokens=0,
    cache_creation_input_tokens=0,
    cache_read_input_tokens=0,
  )
  assert summary.anomalies == ()


def test_a_malformed_line_is_skipped_and_reported() -> None:
  """A crash mid-write can cut a line short; the intact records still sum."""
  transcript = _make_raw_transcript(
    [
      '{"message": {"usage": {"input_tokens": 10}}}',
      '{"message": {"usage": {"input_toke',
    ]
  )

  summary = usage_summary([transcript])

  assert summary.totals.input_tokens == 10
  assert len(summary.anomalies) == 1
  assert 'malformed' in summary.anomalies[0]


def test_an_unexpected_usage_field_is_reported_once_per_sweep() -> None:
  """A drifted usage schema yields one report, not one per record."""
  transcript = _make_transcript(
    [
      _make_usage_record({'input_tokens': 10, 'thinking_tokens': 3}),
      _make_usage_record({'input_tokens': 5, 'thinking_tokens': 4}),
    ]
  )

  summary = usage_summary([transcript])

  assert summary.totals.input_tokens == 15  # the known counters still sum
  reports = [
    anomaly for anomaly in summary.anomalies if 'thinking_tokens' in anomaly
  ]
  assert len(reports) == 1


def test_a_non_integer_counter_is_reported_and_left_uncounted() -> None:
  """A counter that isn't a number can't be summed, so it's flagged instead."""
  transcript = _make_transcript(
    [
      _make_usage_record({'input_tokens': 'lots'}),
      _make_usage_record({'input_tokens': 10}),
    ]
  )

  summary = usage_summary([transcript])

  assert summary.totals.input_tokens == 10
  assert len(summary.anomalies) == 1
  assert 'non-integer' in summary.anomalies[0]


# --- session_transcript_paths ---


def test_transcript_without_subagents_yields_only_itself() -> None:
  """No subagents directory means the main transcript is the whole session."""
  transcript = Path('/nonexistent/project/session.jsonl')

  assert list(session_transcript_paths(transcript)) == [transcript]
