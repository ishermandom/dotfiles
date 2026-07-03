#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for the pure formatting and log-editing logic in session_tokens. The I/O
# paths (transcript summing, hook dispatch) are exercised manually; see the
# module's docstring for the hook contract.

from pathlib import Path

import pytest
from session_tokens import (
  UsageTotals,
  formatted_count,
  session_transcript_paths,
  stats_only_entry,
  tokens_line,
  updated_log_text,
)

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


# --- session_transcript_paths ---


def test_transcript_without_subagents_yields_only_itself() -> None:
  """No subagents directory means the main transcript is the whole session."""
  transcript = Path('/nonexistent/project/session.jsonl')

  assert list(session_transcript_paths(transcript)) == [transcript]
