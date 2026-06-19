#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the instructions-loaded hook's block formatting. The
# formatting is a pure string transform, so it's tested directly without touch-
# ing the filesystem; rotation is covered by log_rotation_test.py.
#   PYTHONPATH=~/.claude/hooks pytest ~/.claude/hooks/log_instructions_loaded_test.py

import log_instructions_loaded as logger


def test_json_payload_is_pretty_printed_under_a_timestamp_header() -> None:
  """A JSON payload is reindented two-space and headed by its timestamp."""
  block = logger.format_block('{"rule":"python.md"}', '2026-06-18T22:14:00Z')

  assert block == ('[2026-06-18T22:14:00Z]\n{\n  "rule": "python.md"\n}\n\n')


def test_unparseable_payload_falls_back_to_raw_text() -> None:
  """A non-JSON payload is recorded verbatim rather than dropped."""
  block = logger.format_block('not json at all', '2026-06-18T22:14:00Z')

  # The raw text survives under the header — the block is never empty.
  assert block == '[2026-06-18T22:14:00Z]\nnot json at all\n\n'
