# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for the prose reflow hook. Run from the hooks directory, or with it on
# PYTHONPATH: PYTHONPATH=~/.claude/hooks python3 -m pytest reflow_prose_test.py

import textwrap
import tokenize
from pathlib import Path

import pytest
from reflow_prose import (
  MarkdownFormatter,
  PrettierError,
  reflow_file,
  reflow_source,
  run_prettier,
)


def fill_markdown(markdown: str, width: int) -> str:
  """Prettier stand-in: fill each paragraph, pass sentinel lines through."""
  filled = []
  for paragraph in markdown.split('\n\n'):
    if paragraph.startswith('<!--'):
      filled.append(paragraph)
    else:
      filled.append(textwrap.fill(' '.join(paragraph.split()), width))
  return '\n\n'.join(filled) + '\n'


def _make_counting_formatter() -> tuple[list[str], MarkdownFormatter]:
  """A fill_markdown wrapper recording each markdown document it formats."""
  calls: list[str] = []

  def formatter(markdown: str, width: int) -> str:
    calls.append(markdown)
    return fill_markdown(markdown, width)

  return calls, formatter


# --- comment reflow ---


def test_overlong_comment_wraps_under_the_prefix() -> None:
  """A comment past 80 columns splits into '# '-prefixed lines within it."""
  source = (
    '# This comment is written as one very long line that runs well past'
    ' the eighty column limit and therefore needs wrapping.\n'
    'x = 1\n'
  )

  result = reflow_source(source, fill_markdown)

  lines = result.split('\n')
  assert all(len(line) <= 80 for line in lines)
  assert lines[0].startswith('# This comment')
  assert lines[1].startswith('# ')
  # Modulo the '# ' prefixes, the prose is word-for-word intact.
  assert result.replace('# ', ' ').split() == source.replace('# ', ' ').split()


def test_ragged_comment_lines_merge_into_one_paragraph() -> None:
  """Adjacent short prose lines refill into a single full line."""
  source = '# alpha beta\n# gamma delta\nx = 1\n'

  result = reflow_source(source, fill_markdown)

  assert result == '# alpha beta gamma delta\nx = 1\n'


def test_blank_comment_line_keeps_paragraphs_separate() -> None:
  """Short lines split by a bare '#' are separate paragraphs; none merge."""
  source = '# alpha beta\n#\n# gamma delta\nx = 1\n'

  assert reflow_source(source, fill_markdown) == source


def test_adjacent_license_header_lines_do_not_merge() -> None:
  """License tag lines are verbatim even though markdown would merge them."""
  source = (
    '# Copyright 2026 Ilya Sherman (ishermandom@)\n'
    '# SPDX-License-Identifier: MIT\n'
    '#\n'
    '# ragged one\n'
    '# ragged two\n'
    'x = 1\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result == (
    '# Copyright 2026 Ilya Sherman (ishermandom@)\n'
    '# SPDX-License-Identifier: MIT\n'
    '#\n'
    '# ragged one ragged two\n'
    'x = 1\n'
  )


def test_shebang_and_directive_lines_stay_verbatim() -> None:
  """Machine lines neither reflow nor merge with the prose around them."""
  source = (
    '#!/usr/bin/env python3\n'
    '# one two\n'
    '# three four\n'
    '# type: ignore\n'
    '# five six\n'
    '# seven eight\n'
    'x = 1\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result == (
    '#!/usr/bin/env python3\n'
    '# one two three four\n'
    '# type: ignore\n'
    '# five six seven eight\n'
    'x = 1\n'
  )


def test_fmt_off_region_is_not_reflowed() -> None:
  """Comments inside a fmt: off region pass through untouched."""
  source = (
    '# fmt: off\n'
    '# ragged one\n'
    '# ragged two\n'
    '# fmt: on\n'
    '# tail one\n'
    '# tail two\n'
    'x = 1\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result == (
    '# fmt: off\n'
    '# ragged one\n'
    '# ragged two\n'
    '# fmt: on\n'
    '# tail one tail two\n'
    'x = 1\n'
  )


def test_todo_line_starts_its_own_paragraph() -> None:
  """A TODO never merges into preceding prose; its continuation joins it."""
  source = (
    '# Prose line one.\n'
    '# TODO: fix the frobnicator\n'
    '#   handling soon.\n'
    'x = 1\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result == (
    '# Prose line one.\n# TODO: fix the frobnicator handling soon.\nx = 1\n'
  )


def test_trailing_comment_is_left_alone() -> None:
  """A comment sharing its line with code is never touched."""
  source = (
    'x = 1  # this trailing comment is longer than the eighty column limit'
    ' would ever allow but must stay put anyway\n'
  )

  assert reflow_source(source, fill_markdown) == source


def test_indented_comment_wraps_to_its_narrower_width() -> None:
  """An indented comment reflows and keeps its indent."""
  source = 'def f() -> None:\n  # alpha beta\n  # gamma delta\n  return\n'

  result = reflow_source(source, fill_markdown)

  assert result == 'def f() -> None:\n  # alpha beta gamma delta\n  return\n'


def test_single_line_internal_spacing_normalizes_like_any_prose() -> None:
  """Intra-line runs of spaces collapse uniformly, single-line or not."""
  source = '# foo.  bar\nx = 1\n'

  result = reflow_source(source, fill_markdown)

  assert result == '# foo. bar\nx = 1\n'


def test_section_header_next_to_prose_stays_verbatim() -> None:
  """A '--- subject ---' header never merges into an adjacent comment line."""
  source = (
    '# Setup helpers for the suite below.\n# --- rotation trigger ---\nx = 1\n'
  )

  assert reflow_source(source, fill_markdown) == source


def test_comment_word_prefixed_by_directive_name_reflows() -> None:
  """Prose starting with a word like 'pragmatic' is not a pragma directive."""
  source = '# pragmatic engineering\n# means shipping.\nx = 1\n'

  result = reflow_source(source, fill_markdown)

  assert result == '# pragmatic engineering means shipping.\nx = 1\n'


def test_character_rewrites_fall_back_to_the_plain_filler() -> None:
  """A formatter that escapes characters is overruled by a plain refill."""

  def escape_asterisks(markdown: str, width: int) -> str:
    return markdown.replace('*', '\\*') + '\n'

  source = '# Accepts *args\n# and **kwargs.\nx = 1\n'

  result = reflow_source(source, escape_asterisks)

  # The ragged lines still merge — via the filler, asterisks intact.
  assert result == '# Accepts *args and **kwargs.\nx = 1\n'


# --- docstring reflow ---


def test_overlong_docstring_summary_wraps_with_closing_on_own_line() -> None:
  """A too-long one-line docstring becomes a wrapped block plus closing."""
  source = (
    'def f() -> None:\n'
    '  """Summary that is deliberately much too long to remain on a single'
    ' line within the eighty column limit."""\n'
    '  return\n'
  )

  result = reflow_source(source, fill_markdown)

  lines = result.split('\n')
  assert all(len(line) <= 80 for line in lines)
  assert lines[1].startswith('  """Summary that')
  assert lines[-3] == '  """'  # closing quotes, then 'return', then ''
  # Modulo quote placement, the prose is word-for-word intact.
  assert (
    result.replace('"""', ' ').split() == source.replace('"""', ' ').split()
  )


def test_short_single_line_docstring_is_unchanged() -> None:
  """A docstring already within the limit stays a one-liner."""
  source = 'def f() -> None:\n  """Short."""\n  return\n'

  assert reflow_source(source, fill_markdown) == source


def test_indented_docstring_reflows_and_keeps_its_indent() -> None:
  """Body paragraphs dedent for markdown and re-indent on the way back."""
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  alpha beta\n'
    '  gamma delta\n'
    '  """\n'
    '  return\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result == (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  alpha beta gamma delta\n'
    '  """\n'
    '  return\n'
  )


def test_docstring_with_section_headers_is_left_alone() -> None:
  """Args:-style sections are structure markdown reflow would destroy."""
  source = (
    'def f(x: int) -> None:\n'
    '  """Summary.\n'
    '\n'
    '  Args:\n'
    '    x: meaning\n'
    '  """\n'
    '  return\n'
  )

  assert reflow_source(source, fill_markdown) == source


def test_docstring_with_doctest_is_left_alone() -> None:
  """A >>> prompt marks executable content, not prose."""
  source = 'def f() -> None:\n  """Summary.\n\n  >>> f()\n  """\n  return\n'

  assert reflow_source(source, fill_markdown) == source


def test_docstring_with_bare_code_symbols_reflows() -> None:
  """Docstrings use the plain filler, so `*args` prose still refills."""
  source = (
    'def f() -> None:\n  """Accepts *args\n  and **kwargs.\n  """\n  return\n'
  )

  result = reflow_source(source, run_prettier)

  assert result == (
    'def f() -> None:\n  """Accepts *args and **kwargs."""\n  return\n'
  )


def test_docstring_bullet_list_wraps_under_a_hanging_indent() -> None:
  """List items in a docstring refill beneath their marker."""
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  - a bullet item that is comfortably longer than the eighty column'
    ' limit and so must wrap beneath its marker\n'
    '  - short item\n'
    '  """\n'
    '  return\n'
  )

  result = reflow_source(source, run_prettier)

  lines = result.split('\n')
  assert all(len(line) <= 80 for line in lines)
  assert lines[3].startswith('  - a bullet')
  assert lines[4].startswith('    ')  # continuation hangs under the marker
  assert '  - short item' in lines


def test_docstring_numbered_list_is_not_renumbered() -> None:
  """Deliberate numbering is content; the filler never rewrites it."""
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  1. first step\n'
    '  3. deliberately step three\n'
    '  """\n'
    '  return\n'
  )

  assert reflow_source(source, run_prettier) == source


def test_docstring_fenced_code_stays_verbatim() -> None:
  """Fenced blocks pass through while surrounding prose refills."""
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  ```\n'
    '  ragged code    with meaningful spacing\n'
    '  ```\n'
    '  """\n'
    '  return\n'
  )

  assert reflow_source(source, run_prettier) == source


def test_docstring_long_url_overflows_unbroken() -> None:
  """An unbreakable word is left overlong rather than split."""
  url = 'https://example.com/' + 'a' * 70
  source = f'def f() -> None:\n  """See {url} here.\n  """\n  return\n'

  result = reflow_source(source, run_prettier)

  assert url in result  # the URL survives as one token on its own line


def test_non_ascii_docstring_reflows_without_corruption() -> None:
  """ast column offsets are UTF-8 bytes; em-dashes must not shift the slice."""
  source = (
    'def f() -> None:\n'
    '  """Summary — with em-dashes — that is deliberately much too long to'
    ' remain on a single line."""\n'
    '  return\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result.count('"""') == 2
  assert all(len(line) <= 80 for line in result.split('\n'))
  assert (
    result.replace('"""', ' ').split() == source.replace('"""', ' ').split()
  )


def test_prose_continuing_onto_an_ordinal_line_merges() -> None:
  """Only a bullet or '1.' may interrupt a paragraph, mirroring CommonMark."""
  source = (
    'def f() -> None:\n'
    '  """We refer readers to section\n'
    '  3. of the paper for the derivation.\n'
    '  """\n'
    '  return\n'
  )

  result = reflow_source(source, fill_markdown)

  assert result == (
    'def f() -> None:\n'
    '  """We refer readers to section 3. of the paper for the derivation."""\n'
    '  return\n'
  )


@pytest.mark.parametrize('marker', ['- ', '1. '])
def test_bare_list_marker_does_not_swallow_the_next_paragraph(
  marker: str,
) -> None:
  """An empty list marker stays its own line; filling it would restructure.

  The bullet exercises the rule-line branch; the bare `1.` exercises the
  empty-marker branch inside the list-item path.
  """
  # The trailing space in the marker is load-bearing: the list-marker pattern
  # requires whitespace after the marker, so the space is what makes this a bare
  # marker rather than plain prose.
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    f'  {marker}\n'
    '  tail words follow.\n'
    '  """\n'
    '  return\n'
  )

  result = reflow_source(source, fill_markdown)

  assert f'{marker}tail words follow.' not in result
  assert '  tail words follow.' in result


def test_todo_under_a_bullet_stays_nested_in_its_item() -> None:
  """Inside a list item a TODO is item content, not a fresh paragraph."""
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  - item start\n'
    '    TODO: finish this\n'
    '  """\n'
    '  return\n'
  )

  result = reflow_source(source, fill_markdown)

  # The continuation merges into the item rather than being promoted to a
  # flush-left paragraph outside the list.
  assert '  - item start TODO: finish this' in result


def test_todo_in_docstring_keeps_its_own_paragraph() -> None:
  """The TODO-on-its-own-line rule holds inside docstrings too."""
  source = (
    'def f() -> None:\n'
    '  """Summary.\n'
    '\n'
    '  Does the thing.\n'
    '  TODO: handle the empty case.\n'
    '  """\n'
    '  return\n'
  )

  assert reflow_source(source, fill_markdown) == source


def test_raw_docstring_is_left_alone() -> None:
  """A prefixed string literal is never rewritten."""
  source = (
    'def f() -> None:\n'
    '  r"""Raw summary that is much too long to remain on a single line'
    ' within the eighty column limit but must stay."""\n'
    '  return\n'
  )

  assert reflow_source(source, fill_markdown) == source


# --- error handling ---


def test_carriage_return_source_is_left_alone() -> None:
  """A source with any CR skips reflow rather than gaining mixed endings."""
  source = '# alpha beta\r\n# gamma delta\r\nx = 1\r\n'

  assert reflow_source(source, fill_markdown) == source


def test_crlf_file_on_disk_is_left_untouched(tmp_path: Path) -> None:
  """The CRLF skip must survive file reading.

  This is the one behavior a stream cannot exercise: read_text's
  universal-newline translation would strip the CR before reflow_source could
  see it, so the guard is only proven against a real file.
  """
  target = tmp_path / 'crlf_module.py'
  crlf_bytes = b'# alpha beta\r\n# gamma delta\r\nx = 1\r\n'
  target.write_bytes(crlf_bytes)

  changed = reflow_file(target, fill_markdown)

  assert not changed
  assert target.read_bytes() == crlf_bytes


def test_syntax_error_propagates() -> None:
  """Broken source raises rather than risking a bad rewrite."""
  # The tokenizer reports this as TokenError; ast.parse reports other breaks as
  # SyntaxError. Callers must handle both, so both satisfy the contract.
  with pytest.raises((SyntaxError, tokenize.TokenError)):
    reflow_source('def broken(:\n', fill_markdown)


# --- formatter dispatch ---


def test_same_width_chunks_share_one_formatter_call() -> None:
  """Chunks of equal width batch into a single formatter invocation."""
  calls, counting_fill = _make_counting_formatter()
  source = (
    '# alpha beta\n# gamma delta\nx = 1\n# epsilon zeta\n# eta theta\ny = 2\n'
  )

  result = reflow_source(source, counting_fill)

  # Two multi-line comment chunks, same indent, same width: exactly one call.
  assert len(calls) == 1
  assert result == (
    '# alpha beta gamma delta\nx = 1\n# epsilon zeta eta theta\ny = 2\n'
  )


def test_already_formatted_multi_line_comment_skips_the_formatter() -> None:
  """A block at the greedy-fill fixed point starts no formatter call."""
  calls, counting_fill = _make_counting_formatter()
  # 76 chars of words: the first line is full at 78, so 'tail' cannot merge up
  # and the block is already at its fixed point.
  full_line_words = ' '.join(['w' * 10] * 7)
  source = f'# {full_line_words}\n# tail\nx = 1\n'

  result = reflow_source(source, counting_fill)

  assert result == source
  assert not calls


def test_prettier_failure_degrades_to_plain_fill() -> None:
  """An unreachable prettier degrades to the filler, never blocking edits."""

  def broken_formatter(markdown: str, width: int) -> str:
    raise PrettierError('prettier is unavailable')

  source = '# alpha beta\n# gamma delta\nx = 1\n'

  result = reflow_source(source, broken_formatter)

  assert result == '# alpha beta gamma delta\nx = 1\n'


def test_swallowed_separator_falls_back_to_per_chunk_calls() -> None:
  """A formatter that eats the sentinel still yields a correct reflow."""

  def separator_eating_fill(markdown: str, width: int) -> str:
    return fill_markdown(
      markdown.replace('<!-- reflow-chunk-boundary -->', ''), width
    )

  source = (
    '# alpha beta\n# gamma delta\nx = 1\n# epsilon zeta\n# eta theta\ny = 2\n'
  )

  result = reflow_source(source, separator_eating_fill)

  assert result == (
    '# alpha beta gamma delta\nx = 1\n# epsilon zeta eta theta\ny = 2\n'
  )


# --- integration with real prettier ---


def test_prettier_wraps_bullets_with_hanging_indent() -> None:
  """Markdown structure in comments survives and wraps correctly."""
  source = (
    '# - a bullet list item that is comfortably longer than the eighty'
    ' column limit and so must wrap beneath its own marker\n'
    '# - short item\n'
    'x = 1\n'
  )

  result = reflow_source(source, run_prettier)

  lines = result.split('\n')
  assert all(len(line) <= 80 for line in lines)
  assert lines[0].startswith('# - a bullet')
  assert lines[1].startswith('#   ')  # continuation under the marker


def test_setext_heading_underline_survives_the_filler_fallback() -> None:
  """A dash-run underline is structure even when emphasis forces the filler."""
  # The *emphasis* makes real prettier rewrite characters, so the whole chunk
  # falls back to the plain filler — which must still keep the heading and its
  # underline on their own lines.
  source = (
    '# Threat model\n'
    '# ------------\n'
    '# The concern is *unrecoverable* destructive change to the working tree'
    ' and it must wrap here.\n'
    'x = 1\n'
  )

  result = reflow_source(source, run_prettier)

  assert '# Threat model\n# ------------\n' in result
  assert 'model ------------' not in result


def test_prettier_emphasis_rewrite_falls_back_to_plain_fill() -> None:
  """Real prettier escapes bare asterisks; the filler still merges the prose."""
  source = '# Accepts *args and\n# **kwargs in its signature.\nx = 1\n'

  result = reflow_source(source, run_prettier)

  assert result == '# Accepts *args and **kwargs in its signature.\nx = 1\n'


def test_reflow_is_idempotent_with_prettier() -> None:
  """Reflowing already-reflowed source changes nothing."""
  source = (
    '# A first paragraph that is long enough to be wrapped by the reflow'
    ' pass when it runs.\n'
    '#\n'
    '# ragged tail one\n'
    '# ragged tail two\n'
    'x = 1\n'
  )

  once = reflow_source(source, run_prettier)
  twice = reflow_source(once, run_prettier)

  assert twice == once
