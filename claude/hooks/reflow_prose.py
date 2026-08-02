#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PostToolUse(Edit|Write) hook: reflow comment and docstring prose in a
# just-edited Python or shell file to the line width that file's project uses,
# or 80 columns by default.
#
# Formatters deliberately leave comment and docstring text alone — ruff and
# shfmt both do — so fitting prose to the line limit is manual work. This hook
# closes that gap with two engines that both split overlong lines and merge
# ragged short ones, paragraph by paragraph: comments go through prettier
# (`--parser=markdown --prose-wrap=always`) for markdown-aware layout, and
# docstrings through a plain word-preserving filler (see below for why).
#
# Where the comments come from differs by language and neither is a line scan.
# Python's come from `tokenize`, shell's from `shfmt --to-json` — so a `#` line
# inside a heredoc, which a scan would take for a comment, is correctly left
# alone. Shell has no docstring equivalent, so comments are its whole job.
#
# The contract that makes this safe:
#
# - Comment prose is markdown, and a chunk is a run of adjacent `# ` lines: a
#   blank comment line ends the chunk, so paragraphs are separated by being
#   formatted as separate documents. Adjacent plain lines are one paragraph and
#   will merge. Bullets are `-`: prettier rewrites `*` and `+` to `-`, which
#   trips the word-preservation check below and drops the whole chunk to the
#   plain filler.
# - Structure that survives reflow intact: `-` bullet lists (continuations wrap
#   under a hanging indent), ordered lists numbered from `1.`, fenced blocks,
#   tables, headings, and blockquotes. Nested bullets survive too, reindented to
#   two spaces. One shape does not: an ordered list numbered from anything but
#   `1.` merges into the paragraph above, since only `1.` may interrupt a
#   paragraph.
# - An indented comment line is a verbatim block (a usage listing, a shell setup
#   recipe) rather than prose to refill, so it keeps its shape without needing a
#   blank comment line above it. Markdown would instead read it as a lazy
#   continuation and flatten it into the paragraph above, which for source
#   comments is corruption far more often than it is the author's intent. Two
#   exceptions: a line under an open list item, whose continuations are indented
#   by nature, and anything inside a fenced block. The rule errs toward
#   declining: indented prose that would have refilled cleanly simply stays put.
#   Docstrings are the exception to all of this — the plain filler holds a line
#   verbatim only from four spaces, markdown's own code-block threshold, so a
#   shallower indented block inside a docstring still merges into the paragraph
#   above it unless a blank line precedes it.
# - Reflow never changes a chunk's line density. A chunk holds no blank line, so
#   every blank line prettier emits is structure it added — splitting a list off
#   the paragraph that introduces it, say — and is dropped. Density stays the
#   author's call, expressed by the blank comment lines bounding the chunk.
# - Reflow may only move whitespace. A markdown formatter assumes a renderer
#   will absorb its notation changes — in a .md file, an escaped `\*` renders
#   back to `*`, so the rewrite is invisible. Source text has no rendering step:
#   the raw characters are what the reader (and `help()`) sees, so a private
#   name escaped to `\_logger`, a documented ```-fence collapsed to single
#   backticks, or a line-leading `>=` split into a blockquote's `> =` is plain
#   corruption. When prettier changes any character, the chunk is refilled by a
#   plain filler that never rewrites characters; if even that fails the
#   word-preservation check, the chunk keeps its original text.
# - Machine directives never reflow: shebangs, `noqa`, `fmt:`, `type:`,
#   `shellcheck`, and kin are configuration, not prose, as is any region under
#   `fmt: off`. Wrapping a `shellcheck disable=` line, or letting it merge into
#   neighboring prose, would silently stop suppressing anything. License tag
#   lines (`Copyright`, `SPDX-License-Identifier`) are likewise verbatim — to
#   markdown they are adjacent one-line paragraphs that would otherwise merge.
#   Only those two tag forms are recognized: an Apache-style boilerplate block
#   or any other header format reflows as ordinary prose, so keep headers in the
#   two-line form. Tab-indented comments are skipped wholesale: reinsertion is
#   spaces-only math, so touching them would rewrite a tab file's indentation.
#
# Docstrings reflow only in the common shape: plain triple quotes with the
# summary starting right after them. A docstring carrying a doctest or an
# Args:-style section reflows only its prose head; the structured tail stays
# verbatim. Docstrings always use the plain filler, never prettier: their prose
# is dense with code symbols (`*args`, private `_names`, `>=`), and a survey of
# real repos showed prettier rewriting characters in a meaningful share of them
# — including a filename turned into `eval*panel.py` by emphasis pairing. Under
# the filler the word-preservation check is an invariant, not a coverage leak.
#
# docformatter (the ecosystem's dedicated docstring wrapper) is no substitute
# for the filler: it rewrites characters by design (adding summary periods,
# say), so it cannot sit under the word-preservation check; it refuses to wrap
# list items at all; and on Args:/doctest shapes it either bails on the whole
# docstring or, with --force-wrap, collapses the section into one filled
# paragraph — where this tool reflows just the head. Its distinct value — PEP
# 257 normalization — is a linting concern, not reflow.
#
# Invoke with file paths to reflow them directly, or with no arguments to read a
# hook payload (JSON with .tool_input.file_path) from stdin. A file whose parser
# rejects it is left unchanged by design: mid-turn edits pass through broken
# states, and the real syntax errors are reported by ruff at Stop or by
# shellcheck through `quiet-shell.sh`. A shell file is likewise left alone when
# shfmt is missing or hangs — silently, the way a missing ruff falls back to the
# default width, since reflow is best-effort and must never block the edit loop.

import ast
import dataclasses
import enum
import io
import json
import os
import re
import subprocess
import sys
import textwrap
import time
import tokenize
from collections.abc import Callable, Iterator, Mapping, Sequence
from pathlib import Path

# Width for a file whose project states none — the 80-column house style.
DEFAULT_LINE_WIDTH = 80

# The shell files to reflow, matching the paths `rules/shell.md` governs. The
# startup files carry no extension and are recognized by name instead.
_SHELL_SUFFIXES = frozenset({'.bash', '.sh', '.zsh'})
_SHELL_FILENAMES = frozenset({'.zprofile', '.zshrc'})

# `ruff check --show-settings` prints a file's resolved configuration as
# `key = value` lines. The formatter's wrap width is the one prose should match,
# since it is where ruff breaks the code around that prose.
_LINE_WIDTH_PATTERN = re.compile(
  r'^formatter\.line_width = (?P<width>\d+)$', re.MULTILINE
)

# Formats a markdown document to a print width; comment chunks go through this.
# reflow_source() takes it as a dependency so tests can substitute a
# deterministic one.
MarkdownFormatter = Callable[[str, int], str]

# prettier starts a fresh subprocess per call, and one call formats at a single
# --print-width — but a chunk's width varies with its indent (the leading spaces
# and `# ` prefix eat columns). So chunks that share a print width are joined by
# this sentinel, formatted in one call, and split apart after, rather than
# paying a subprocess start per chunk. As an HTML comment the sentinel forms its
# own markdown paragraph and passes through prettier verbatim.
_CHUNK_SEPARATOR = '<!-- reflow-chunk-boundary -->'

# Directive names that mark a whole-line comment as machine configuration
# (linter suppressions, formatter and type-checker switches), not prose. The
# bare names take `\b` so prose like "pragmatic" isn't misread. `fmt:` here also
# owns stray non-region fmt directives (`fmt: skip`, an unmatched `fmt: on`);
# the region patterns below handle only off/on toggling. shellcheck's entry
# takes its whole `key=value` shape rather than the bare name: every directive
# it has is one (`disable=`, `source=`, `shell=`, and kin), and "shellcheck" is
# an ordinary word in this repo's shell prose that a bare name would freeze.
_DIRECTIVE_NAMES = (
  r'noqa\b|fmt:|type:|mypy:|ruff:|pyright:|pragma\b|shellcheck\s+[a-z-]+='
)
_DIRECTIVE_PATTERN = re.compile(rf'\s*(?:{_DIRECTIVE_NAMES})')

# `fmt: off` opens a hands-off region that `fmt: on` closes, matching the
# formatter's own convention.
_FORMAT_OFF_PATTERN = re.compile(r'\s*fmt:\s*off\b')
_FORMAT_ON_PATTERN = re.compile(r'\s*fmt:\s*on\b')

# The style guide puts every TODO on its own line; starting a fresh paragraph at
# each TODO keeps one from merging into neighboring prose.
_TODO_PATTERN = re.compile(r'\s*TODO\b')

# License-header tag lines stay verbatim: they read as adjacent one-line
# paragraphs, and merging a legal header is not this tool's call to make.
_LICENSE_TAG_NAMES = r'Copyright\b|SPDX-License-Identifier:'
_LICENSE_TAG_PATTERN = re.compile(rf'\s*(?:{_LICENSE_TAG_NAMES})')

# Google-style docstring section headers introduce indented structure that
# markdown reflow would merge, so a header marks where a docstring's verbatim
# tail begins.
_SECTION_NAMES = (
  r'Args|Arguments|Attributes|Examples?|Notes?|Raises|Returns|Yields'
)
_SECTION_HEADER_PATTERN = re.compile(rf'^\s*(?:{_SECTION_NAMES}):\s*$')

_DOCSTRING_OWNER_TYPES = (
  ast.Module,
  ast.ClassDef,
  ast.FunctionDef,
  ast.AsyncFunctionDef,
)

# List markers the plain filler recognizes; the marker's width sets the hanging
# indent for the item's continuation lines. A marker needs trailing whitespace,
# so `*args` at the start of a line stays ordinary prose.
_LIST_ITEM_PATTERN = re.compile(r'(?P<indent>\s*)(?P<marker>[-*+]|\d+\.)\s+')

# Line-leading characters that signal structure the plain filler shouldn't
# rewrap: headings, block quotes and doctest prompts, tables, HTML.
_STRUCTURAL_PREFIXES = ('#', '>', '|', '<!--')

# A code fence opens or closes a verbatim region.
_FENCE_PREFIXES = ('```', '~~~')

# A line of only rule characters (optionally spaced) is a setext heading
# underline or a thematic break — structure, not prose. Merging one into a
# paragraph would pass the word-preservation check (the run is its own token),
# so it must be recognized here.
_RULE_CHARACTER = r'[-=*_]'
_RULE_LINE_PATTERN = re.compile(rf'\s*(?:{_RULE_CHARACTER}[ \t]*)+$')

# The `# --- subject ---` section headers the style guide mandates for tests are
# likewise structure: dashes flank the text, so no other pattern claims them,
# and an adjacent prose line would otherwise absorb them. Three dashes minimum,
# so a `-- like this --` prose aside still reflows as prose.
_DECORATED_HEADING_PATTERN = re.compile(r'\s*-{3,}\s.*-{3,}\s*$')


class PrettierError(Exception):
  """prettier exited nonzero or could not be run."""


class ShellParseError(Exception):
  """shfmt could not report a shell source's comments.

  Covers a missing or hanging shfmt as well as source it rejects: the caller
  cannot tell comments from heredoc text without it, so every case means the
  same thing — leave the file alone.
  """


class Language(enum.Enum):
  """A source language this hook knows how to find the comments of."""

  PYTHON = enum.auto()
  SHELL = enum.auto()


class ChunkKind(enum.Enum):
  """What kind of source construct a prose chunk came from."""

  COMMENT = enum.auto()
  DOCSTRING = enum.auto()


@dataclasses.dataclass(frozen=True)
class ProseChunk:
  """One markdown document to reflow, with what's needed to reinsert it.

  Line numbers are 1-indexed and inclusive; `indent` is the column where the `#`
  or opening quotes sit, applied to every reinserted line; `line_width` is the
  width the reinserted source lines have to fit.
  """

  kind: ChunkKind
  first_line: int
  last_line: int
  indent: int
  markdown: str
  line_width: int

  # A docstring chunk covering only the prose head above a structured section
  # stops before the closing triple-quote, which stays with the untouched tail;
  # `_render` then omits it. Always True for comments and whole docstrings.
  closes_docstring: bool = True

  def reflow_width(self) -> int:
    """Print width for the markdown text, net of indent and prefix."""
    if self.kind is ChunkKind.COMMENT:
      return max(1, self.line_width - self.indent - len('# '))
    return max(1, self.line_width - self.indent)


@dataclasses.dataclass(frozen=True)
class _CommentLine:
  """A whole-line comment: its indent column and text after the `#`."""

  indent: int
  content: str


def _tool_environment() -> Mapping[str, str]:
  """The process environment with both Homebrew bin directories on PATH.

  Hooks can run with a minimal environment, and the three subprocesses this hook
  shells out to — prettier, ruff, and shfmt — usually live in one of those
  directories.
  """
  environment = dict(os.environ)
  environment['PATH'] = '/opt/homebrew/bin:/usr/local/bin:' + environment.get(
    'PATH', ''
  )
  return environment


def run_prettier(markdown: str, width: int) -> str:
  """Reflow a markdown document with prettier at the given print width."""
  # `--no-config` shields the reflow from project-level prettier settings: a
  # project with `proseWrap: never` would otherwise unwrap every comment.
  # Changing flags here interacts with the fixed-point skip in _reflow_chunks:
  # chunks the plain filler wouldn't change never reach prettier at all.
  command = [
    'prettier',
    '--no-config',
    '--parser=markdown',
    '--prose-wrap=always',
    f'--print-width={width}',
  ]
  # Every way the subprocess can fail becomes PrettierError, which
  # _reflow_chunks degrades to the plain filler: spawn failure (OSError), a hang
  # (TimeoutExpired — without it the harness would SIGKILL the whole hook), and
  # non-UTF-8 output (UnicodeDecodeError from text mode).
  try:
    result = subprocess.run(
      command,
      input=markdown,
      text=True,
      capture_output=True,
      env=_tool_environment(),
      timeout=10,
    )
  except (OSError, subprocess.TimeoutExpired, UnicodeDecodeError) as error:
    raise PrettierError(
      f'could not run prettier: {error}\n'
      f'on markdown starting: {markdown[:200]!r}'
    ) from error
  if result.returncode != 0:
    raise PrettierError(
      f'prettier exited {result.returncode}: {result.stderr.strip()[:500]}\n'
      f'on markdown starting: {markdown[:200]!r}'
    )
  return result.stdout


@dataclasses.dataclass
class _FillUnit:
  """The paragraph or list item currently being accumulated for a fill.

  Collects words until the surrounding structure ends the unit; flush() renders
  them as lines filled to `width` under the unit's indents and empties the unit
  for the next one.
  """

  width: int
  words: list[str] = dataclasses.field(default_factory=list)
  first_indent: str = ''
  hanging_indent: str = ''

  def start_list_item(self, item: re.Match[str]) -> None:
    """Begin a unit for a list item; continuations hang under its marker."""
    self.first_indent = f'{item["indent"]}{item["marker"]} '
    self.hanging_indent = ' ' * len(self.first_indent)
    self.words.extend(item.string[item.end() :].split())

  def add_prose(self, line: str) -> None:
    """Append a plain prose line's words to the unit."""
    self.words.extend(line.split())

  def flush(self) -> Sequence[str]:
    """Render the unit as filled lines, resetting every field on the way out.

    The reset covers the indents, not just the words: a bare list marker sets
    indents without contributing any words, and they must not leak into the next
    unit.
    """
    text = ' '.join(self.words)
    first_indent = self.first_indent
    hanging_indent = self.hanging_indent
    self.words.clear()
    self.first_indent = ''
    self.hanging_indent = ''
    if not text:
      return []
    return textwrap.fill(
      text,
      self.width,
      initial_indent=first_indent,
      subsequent_indent=hanging_indent,
      # Never split a word (a long URL overflows whole, as prettier would leave
      # it) — splitting would fail word preservation.
      break_long_words=False,
      break_on_hyphens=False,
    ).split('\n')


def _starts_list_item(item: re.Match[str], unit: _FillUnit) -> bool:
  """Whether a matched marker opens a list item where it stands.

  Mirrors CommonMark's paragraph-interruption rule (and so prettier): at a
  paragraph break, or as a sibling of an open list item, any marker starts an
  item; mid-paragraph only a bullet or `1.` does, so wrapped prose that happens
  to continue onto `3. of the paper` stays prose.
  """
  return (
    not unit.words
    or bool(unit.hanging_indent)
    or item['marker'] in ('-', '*', '+', '1.')
  )


def fill_prose(markdown: str, width: int) -> str:
  """Reflow markdown-ish prose without ever rewriting a character.

  The model covers exactly: blank-line-separated paragraphs; bullet and numbered
  list items (hanging indents, CommonMark's paragraph-interruption rule); fenced
  blocks and heading underlines kept verbatim; and verbatim structural lines
  (code indents, quotes, tables, headings, HTML). Everything else is plain
  prose. Deliberate non-goals — lazy continuations, blockquote refill,
  nested-list reindentation — stay as prose or verbatim lines rather than
  gaining rules here.

  Unlike prettier, nothing is escaped or normalized — bare `*args` and friends
  survive — so this is both the docstring engine and the fallback when
  prettier's output fails the word-preservation check.
  """
  output: list[str] = []
  unit = _FillUnit(width)
  is_in_fence = False

  for line in markdown.split('\n'):
    stripped = line.strip()

    if is_in_fence:
      output.append(line)
      if stripped.startswith(_FENCE_PREFIXES):
        is_in_fence = False
      continue
    if stripped.startswith(_FENCE_PREFIXES):
      output.extend(unit.flush())
      output.append(line)
      is_in_fence = True
      continue

    if not stripped:
      output.extend(unit.flush())
      output.append('')
      continue

    # An item marker opens a new fill unit, checked before the code-indent rule
    # so nested bullets refill. Rule lines are checked first: `- - -` would
    # otherwise parse as a bullet item.
    if _RULE_LINE_PATTERN.match(line):
      output.extend(unit.flush())
      output.append(line)
      continue
    item = _LIST_ITEM_PATTERN.match(line)
    if item and _starts_list_item(item, unit):
      output.extend(unit.flush())
      # An empty marker stays verbatim: filling the next paragraph into it would
      # restructure, not reflow.
      if not line[item.end() :].strip():
        output.append(line)
        continue
      unit.start_list_item(item)
      continue

    if (
      stripped.startswith(_STRUCTURAL_PREFIXES)
      or line.startswith('    ')
      or _DECORATED_HEADING_PATTERN.match(line)
    ):
      output.extend(unit.flush())
      output.append(line)
      continue

    # A TODO keeps its own paragraph (the style guide puts every TODO on its own
    # line) — but only outside a list item: under a bullet, the TODO is item
    # content and breaking it out would flatten the nesting. Comments rely on
    # the equivalent chunk split in _comment_chunks; docstrings rely on this
    # branch — each engine needs its own.
    if _TODO_PATTERN.match(line) and not unit.hanging_indent:
      output.extend(unit.flush())
    unit.add_prose(line)
  output.extend(unit.flush())
  return '\n'.join(output)


def _full_line_comments(source: str) -> Mapping[int, _CommentLine]:
  """Map line number to comment for every whole-line comment in the source.

  Trailing comments (code before the `#`) are excluded: reflowing one would mean
  moving it off its statement, which is restructuring, not reflow.

  Tab-indented comments are excluded too — silently, so a tab-indented file is
  simply never reflowed rather than corrupted: reinsertion rebuilds indentation
  as `' ' * indent`, which would rewrite tabs into spaces (and tokenize's column
  counts don't equal display columns when tabs are involved).
  """
  comments: dict[int, _CommentLine] = {}
  for token in tokenize.generate_tokens(io.StringIO(source).readline):
    if token.type != tokenize.COMMENT:
      continue
    row, column = token.start
    before = token.line[:column]
    # Tab-indented lines would break the spaces-only reinsertion math.
    if before.strip() or '\t' in before:
      continue
    comments[row] = _CommentLine(column, token.string[1:].rstrip())
  return comments


def _shfmt_parse_tree(source: str) -> object:
  """Parse shell source with shfmt, returning its syntax tree as parsed JSON.

  Raises ShellParseError whenever no tree comes back, which the caller treats as
  a file to leave alone.
  """
  # `--to-json` reads stdin only — it rejects a path argument outright — so the
  # source is piped rather than the file being named.
  try:
    result = subprocess.run(
      ['shfmt', '--to-json'],
      input=source,
      text=True,
      capture_output=True,
      env=_tool_environment(),
      # A cap on a pathological hang, nothing more: parsing costs milliseconds,
      # like the ruff call in _discover_line_width. Both run to completion
      # before any prettier work starts, so the three budgets are additive, and
      # 3 + 2 + the 25 that _reflow_chunks can spend already reaches the
      # 30-second hook timeout in settings.json — which is what keeps this cap
      # at 2 rather than prettier's 10. Simultaneous worst cases would still
      # overrun it by whatever the interpreter and the file read cost, and the
      # harness would kill the hook; the file is then left unchanged, the same
      # outcome every other failure here produces.
      timeout=2,
    )
  except (OSError, subprocess.TimeoutExpired, UnicodeDecodeError) as error:
    raise ShellParseError(f'could not run shfmt: {error}') from error
  if result.returncode != 0:
    raise ShellParseError(
      f'shfmt exited {result.returncode}: {result.stderr.strip()[:500]}'
    )
  try:
    return json.loads(result.stdout)
  except json.JSONDecodeError as error:
    raise ShellParseError(
      f'shfmt emitted no parseable tree: {error}'
    ) from error


def _json_objects(node: object) -> Iterator[Mapping[str, object]]:
  """Every object in a parsed-JSON tree, outermost first."""
  if isinstance(node, dict):
    yield node
    for value in node.values():
      yield from _json_objects(value)
  elif isinstance(node, list):
    for value in node:
      yield from _json_objects(value)


def _shell_comments(source: str) -> Mapping[int, _CommentLine]:
  """Map line number to comment for every whole-line comment in shell source.

  shfmt hangs each comment off the statement it neighbors, at no fixed depth, so
  the tree is walked whole and comment nodes are recognized by shape: a `Hash`
  position paired with the `Text` following it. Keying by line makes the walk
  order irrelevant.

  Trailing and tab-indented comments are excluded for the same reasons as in
  Python, and by the same test against the text preceding the `#`.
  """
  source_lines = source.split('\n')
  comments: dict[int, _CommentLine] = {}
  for node in _json_objects(_shfmt_parse_tree(source)):
    position = node.get('Hash')
    text = node.get('Text')
    if not isinstance(position, Mapping) or not isinstance(text, str):
      continue
    row = position.get('Line')
    column = position.get('Col')
    if not isinstance(row, int) or not isinstance(column, int):
      continue
    # shfmt counts columns from 1; the rest of this module counts from 0.
    column -= 1
    before = source_lines[row - 1][:column]
    if before.strip() or '\t' in before:
      continue
    comments[row] = _CommentLine(column, text.rstrip())
  return comments


def _is_verbatim_line(content: str) -> bool:
  """Whether a comment line is machine, legal, or heading text that must never
  reflow.

  One home for the verbatim policy: shebangs, linter/formatter/type-checker
  directives, license tag lines, `--- subject ---` section headers (which an
  adjacent prose line would otherwise absorb, on the prettier path too), and
  text stuck to the `#` (not this codebase's comment style — don't guess at its
  meaning).
  """
  return (
    content.startswith('!')
    or bool(_DIRECTIVE_PATTERN.match(content))
    or bool(_LICENSE_TAG_PATTERN.match(content))
    or bool(_DECORATED_HEADING_PATTERN.match(content))
    or not content.startswith(' ')
  )


def _comment_chunks(
  comments: Mapping[int, _CommentLine], line_width: int
) -> Sequence[ProseChunk]:
  """Split whole-line comments into reflowable prose chunks.

  A chunk is a maximal run of adjacent `# `-prefixed prose lines at one indent.
  Blank `#` lines, directives, `#`-stuck text, indented blocks, and `fmt: off`
  regions end the current chunk and stay verbatim.
  """
  chunks: list[ProseChunk] = []
  run: list[tuple[int, str]] = []
  is_formatting_disabled = False
  # Both track structure within the current run, so both reset when it ends.
  has_open_list = False
  is_in_fence = False
  previous_row = None
  previous_indent = None

  def flush() -> None:
    nonlocal has_open_list, is_in_fence
    if run:
      text = '\n'.join(line for _, line in run)
      indent = comments[run[0][0]].indent
      chunks.append(
        ProseChunk(
          ChunkKind.COMMENT, run[0][0], run[-1][0], indent, text, line_width
        )
      )
      run.clear()
    has_open_list = False
    is_in_fence = False

  for row in sorted(comments):
    comment = comments[row]
    if row != previous_row or comment.indent != previous_indent:
      flush()
    previous_row = row + 1
    previous_indent = comment.indent

    content = comment.content
    if is_formatting_disabled:
      flush()
      if _FORMAT_ON_PATTERN.match(content):
        is_formatting_disabled = False
      continue
    if _FORMAT_OFF_PATTERN.match(content):
      flush()
      is_formatting_disabled = True
      continue
    # A bare `#` is a paragraph break; keep it verbatim between chunks.
    if not content:
      flush()
      continue
    if _is_verbatim_line(content):
      flush()
      continue

    text = content[1:]
    # A fence opens a verbatim region, where the indent rule below must stay off
    # — fenced content is indented as often as not.
    if text.strip().startswith(_FENCE_PREFIXES):
      is_in_fence = not is_in_fence
    # An indented line is a block to leave alone rather than prose to refill,
    # unless a list item is open, whose continuations are indented by nature.
    elif text[:1].isspace() and not has_open_list and not is_in_fence:
      flush()
      continue
    if _LIST_ITEM_PATTERN.match(text):
      has_open_list = True
    # Comments need the TODO split here — prettier is TODO-blind; docstrings get
    # the equivalent break inside fill_prose. Under an open list item the TODO
    # is item content, so splitting it out would dedent it into a sibling of the
    # bullet — the same carve-out fill_prose makes.
    if _TODO_PATTERN.match(text) and not has_open_list:
      flush()
    run.append((row, text))
  flush()
  return chunks


def _docstring_chunks(
  source: str, source_lines: Sequence[str], tree: ast.Module, line_width: int
) -> Sequence[ProseChunk]:
  """Find docstrings in the common reflowable shape and chunk their prose."""
  chunks: list[ProseChunk] = []
  for node in ast.walk(tree):
    if not isinstance(node, _DOCSTRING_OWNER_TYPES) or not node.body:
      continue
    first_statement = node.body[0]
    if not (
      isinstance(first_statement, ast.Expr)
      and isinstance(first_statement.value, ast.Constant)
      and isinstance(first_statement.value.value, str)
    ):
      continue
    chunk = _docstring_chunk(
      source, source_lines, first_statement.value, line_width
    )
    if chunk:
      chunks.append(chunk)
  return chunks


def _structured_tail_start(content_lines: Sequence[str]) -> int | None:
  """Index of the first content line that begins a structured tail, or None.

  A Google-style section header (`Args:`, `Returns:`, …) or a doctest prompt
  (`>>>`) begins a tail whose indentation markdown reflow would merge. Index 0
  means the docstring opens directly on the tail, with no prose head above; None
  means it is prose all the way down. A header or prompt inside a fenced code
  block is example content, not a boundary, so fenced regions are skipped — the
  same fence-awareness the reflow filler applies.
  """
  # TODO: an indented (non-fenced) code block still isn't recognized, so a
  # header- or prompt-shaped line inside one is misread as the tail start.
  is_in_fence = False
  for index, line in enumerate(content_lines):
    stripped = line.lstrip()
    if stripped.startswith(_FENCE_PREFIXES):
      is_in_fence = not is_in_fence
    elif not is_in_fence and (
      _SECTION_HEADER_PATTERN.match(line) or stripped.startswith('>>>')
    ):
      return index
  return None


def _docstring_chunk(
  source: str,
  source_lines: Sequence[str],
  literal: ast.Constant,
  line_width: int,
) -> ProseChunk | None:
  """Chunk one docstring literal, or None when its shape must stay manual.

  The reflowable shape, in full: the literal sits alone on its lines (space
  indentation only), uses plain unprefixed triple quotes, opens with the summary
  hugging the quotes, and indents every continuation line uniformly. An
  Args:-style section or doctest doesn't disqualify it — only the prose head
  above such a tail is reflowed, and the tail itself stays verbatim. Each guard
  below enforces one clause of that contract.
  """
  first_line = literal.lineno
  last_line = literal.end_lineno
  if last_line is None:
    return None

  # get_source_segment owns the offset math: ast columns are UTF-8 byte offsets,
  # and slicing lines with them by hand overshoots on non-ASCII text (an em-dash
  # is three bytes).
  segment = ast.get_source_segment(source, literal)
  if segment is None:
    return None
  segment_lines = segment.split('\n')

  # Only a docstring alone on its line(s) can be rewritten line-wise: space
  # indentation, the literal, and nothing else. Tab indentation fails the
  # comparison and so stays untouched, like tab-indented comments.
  opening_line = source_lines[first_line - 1]
  indent = len(opening_line) - len(opening_line.lstrip())
  if opening_line.rstrip() != (' ' * indent + segment_lines[0]).rstrip():
    return None
  if (
    last_line != first_line
    and source_lines[last_line - 1].rstrip() != segment_lines[-1].rstrip()
  ):
    return None

  quote = segment[:3]
  # A string prefix (r, f, b) or single quotes means escapes or style we
  # shouldn't rewrite.
  if quote not in ('"""', "'''"):
    return None
  content = segment[3:-3]

  # Reflow only the common shape: summary hugging the opening quotes. An empty
  # docstring, or one opening with whitespace, stays manual.
  if not content or content[0].isspace():
    return None

  # Reflow only the prose head above any structured tail; a tail-less docstring
  # reflows whole.
  content_lines = content.split('\n')
  tail_start = _structured_tail_start(content_lines)
  if tail_start is None:
    head_lines = content_lines
    last_reflowed_line = last_line
    closes = True
  else:
    head_lines = content_lines[:tail_start]
    while head_lines and not head_lines[-1].strip():
      head_lines.pop()
    # No prose head above the tail — nothing to reflow — so leave it manual.
    if not head_lines:
      return None
    last_reflowed_line = first_line + len(head_lines) - 1
    closes = False

  # Continuation lines carry the docstring's indent; strip it so markdown
  # doesn't read indented prose as a code block, and restore it on reinsertion.
  # The first line follows the quotes, so it never carries the indent. Irregular
  # indentation is a shape we don't rewrite.
  dedented = [head_lines[0]]
  for line in head_lines[1:]:
    if not line.strip():
      dedented.append('')
    elif line.startswith(' ' * indent):
      dedented.append(line[indent:])
    else:
      return None

  # Prepending the quotes makes prettier account for their width on the first
  # line; they ride along as ordinary text.
  markdown = (quote + '\n'.join(dedented)).rstrip()
  return ProseChunk(
    ChunkKind.DOCSTRING,
    first_line,
    last_reflowed_line,
    indent,
    markdown,
    line_width,
    closes_docstring=closes,
  )


def _fill_chunk(chunk: ProseChunk) -> str:
  """Reflow one chunk through the plain filler at its own width."""
  return fill_prose(chunk.markdown, chunk.reflow_width())


def _drop_blank_lines(markdown: str) -> str:
  """Strip the blank lines a markdown formatter inserted between blocks.

  A comment chunk carries no blank line of its own — a bare `#` ends the chunk —
  so every blank line here is one the formatter added to set a block apart from
  the paragraph above it. Dropping them keeps a flag legend tight against its
  introducing line; an author wanting the break writes the bare `#`, which
  splits the chunk in two and separates the paragraphs that way.
  """
  return '\n'.join(line for line in markdown.split('\n') if line.strip())


def _reflow_comment_group(
  chunks: Sequence[ProseChunk],
  indices: Sequence[int],
  width: int,
  format_comment_markdown: MarkdownFormatter,
) -> Sequence[str]:
  """Reflow one width group of comment chunks through prettier.

  One subprocess covers the whole group, with a per-chunk retry when a chunk's
  own text breaks the sentinel split (real prettier passes the sentinel through
  verbatim). Failures propagate as PrettierError; the caller owns the
  degradation policy.
  """
  separator = f'\n\n{_CHUNK_SEPARATOR}\n\n'
  combined = separator.join(chunks[i].markdown for i in indices)
  formatted = format_comment_markdown(combined, width)
  parts = formatted.split(_CHUNK_SEPARATOR)
  if len(parts) != len(indices):
    parts = [
      format_comment_markdown(chunks[i].markdown, width) for i in indices
    ]
  # Dropping blank lines also sheds the newlines surrounding the separator.
  return [_drop_blank_lines(part) for part in parts]


def _reflow_chunks(
  chunks: Sequence[ProseChunk], format_comment_markdown: MarkdownFormatter
) -> Sequence[str]:
  """Reflow every chunk through the engine its kind calls for.

  Docstring chunks always use the plain filler (the module header carries the
  why). Comment chunks the filler would leave unchanged are already at the
  reflow fixed point and skip prettier — an already-formatted file starts no
  subprocess at all; the rest go to prettier, batched by width, under one shared
  time budget so the hook can never outlive the harness's patience.
  """
  results = [''] * len(chunks)
  by_width: dict[int, list[int]] = {}
  for index, chunk in enumerate(chunks):
    if chunk.kind is ChunkKind.DOCSTRING:
      results[index] = _fill_chunk(chunk)
      continue
    # The filler performs the same greedy fill as prettier's prose wrap, so a
    # chunk it wouldn't change needs no splitting or merging; prettier could
    # differ only in markdown-structural whitespace — a fidelity trade accepted
    # to keep the common re-save free of subprocess starts. The filler's verdict
    # wins by design: a chunk it calls stable never consults prettier.
    if _fill_chunk(chunk) == chunk.markdown:
      results[index] = chunk.markdown
      continue
    by_width.setdefault(chunk.reflow_width(), []).append(index)

  # All prettier calls share one deadline, kept well under the 30-second hook
  # timeout in settings.json (each call is separately capped at 10 seconds). On
  # the first failure, or once the budget is spent, every remaining group falls
  # back to the plain filler — one breadcrumb, and the edit loop is never
  # blocked. The deadline is checked between calls, so the true worst case is
  # one in-flight call past it: 15 + 10 = 25 seconds, inside the 30-second hook
  # timeout in settings.json.
  deadline = time.monotonic() + 15
  failure: PrettierError | None = None
  for width, indices in by_width.items():
    parts: Sequence[str] | None = None
    if failure is None and time.monotonic() > deadline:
      failure = PrettierError('prettier time budget exhausted')
    if failure is None:
      try:
        parts = _reflow_comment_group(
          chunks, indices, width, format_comment_markdown
        )
      except PrettierError as error:
        failure = error
    if parts is None:
      parts = [_fill_chunk(chunks[i]) for i in indices]
    for index, part in zip(indices, parts):
      results[index] = part
  if failure is not None:
    # The trade is silently losing markdown-aware layout, so leave a breadcrumb
    # on stderr — nothing else surfaces prettier health in a Python-only session
    # (the Stop-time markdown pass swallows its output).
    print(f'reflow_prose: degraded to plain fill: {failure}', file=sys.stderr)
  return results


def _preserves_words(original: str, reflowed: str) -> bool:
  """Whether reflow moved only whitespace, leaving every word intact.

  This is the safety invariant: markdown formatting that escapes or rewrites
  characters (emphasis, blockquotes, list renumbering) fails this check, and the
  chunk keeps its original text.
  """
  return original.split() == reflowed.split()


def _render(chunk: ProseChunk, markdown: str) -> Sequence[str]:
  """Turn reflowed markdown back into source lines for the chunk's slot."""
  prefix = ' ' * chunk.indent
  lines = [line.rstrip() for line in markdown.split('\n')]
  if chunk.kind is ChunkKind.COMMENT:
    return [prefix + ('# ' + line if line else '#') for line in lines]

  rendered = [prefix + line if line else '' for line in lines]

  # Head-only chunk: emit just the prose; the closing quotes ride with the tail.
  if not chunk.closes_docstring:
    return rendered

  quote = markdown[:3]
  closing_inline = f'{prefix}{lines[0]}{quote}'
  if len(lines) == 1 and len(closing_inline) <= chunk.line_width:
    return [closing_inline]
  return [*rendered, prefix + quote]


def reflow_source(
  source: str,
  format_comment_markdown: MarkdownFormatter,
  line_width: int = DEFAULT_LINE_WIDTH,
  language: Language = Language.PYTHON,
) -> str:
  """Reflow all comment and docstring prose in source to `line_width`.

  Raises SyntaxError (or tokenize.TokenError) on Python that doesn't parse, and
  ShellParseError when shfmt cannot report a shell source's comments; the caller
  owns deciding what a source it cannot read means.
  """
  # Any carriage return skips the whole file rather than corrupting it: a CRLF
  # file would come back with reflowed lines LF-only, mixing endings. This
  # deliberately also skips a file with a literal CR byte inside a string
  # constant — rare, and skipping is the safe direction.
  if '\r' in source:
    return source

  source_lines = source.split('\n')
  chunks: Sequence[ProseChunk]
  if language is Language.SHELL:
    chunks = _comment_chunks(_shell_comments(source), line_width)
  else:
    chunks = [
      *_comment_chunks(_full_line_comments(source), line_width),
      *_docstring_chunks(source, source_lines, ast.parse(source), line_width),
    ]
  reflowed = _reflow_chunks(chunks, format_comment_markdown)

  # Replace bottom-up so earlier line numbers stay valid as lengths change.
  by_position = sorted(
    zip(chunks, reflowed), key=lambda pair: pair[0].first_line, reverse=True
  )
  for chunk, markdown in by_position:
    keeps_words = _preserves_words(chunk.markdown, markdown)
    if chunk.kind is ChunkKind.COMMENT and not keeps_words:
      # prettier rewrote a character (an escape, an emphasis marker); refill
      # plainly instead, which sacrifices markdown-aware layout but keeps every
      # character intact. Docstrings already come from the filler, so a second
      # filler pass would just recompute the same text.
      markdown = _fill_chunk(chunk)
      keeps_words = _preserves_words(chunk.markdown, markdown)
    if not keeps_words:
      continue
    source_lines[chunk.first_line - 1 : chunk.last_line] = _render(
      chunk, markdown
    )
  return '\n'.join(source_lines)


def _discover_line_width(path: Path) -> int:
  """The width to reflow a file's prose to: the width its project wraps code at.

  Prose reads best wrapped where the surrounding code wraps, and ruff is asked
  for that width rather than the configuration being read a second time here:
  `--show-settings` reports what a real `ruff format` would use, so every
  configuration file, `extend` chain, and user-level default is already
  accounted for. Whenever ruff cannot answer — not installed, a configuration it
  rejects, output without the setting in it — the 80-column house style stands
  in.

  Shell files ask the same question, since ruff resolves a width from the path's
  directory rather than from what the file contains. That gives a project one
  width across both languages, and a project with no ruff configuration at all
  falls through to the same 80 columns it would have been given anyway.

  The call costs roughly 10 ms, paid on every edit rather than only on the ones
  that reflow something: the width is what decides whether a file is already
  wrapped, so it has to be known before that question can be asked.
  """
  try:
    result = subprocess.run(
      ['ruff', 'check', '--show-settings', str(path)],
      text=True,
      capture_output=True,
      env=_tool_environment(),
      # A cap on a pathological hang, nothing more — see the docstring for what
      # the call actually costs. It stays small enough that the prettier budget
      # in _reflow_chunks can still run to its own worst case within the
      # 30-second hook timeout in settings.json.
      timeout=3,
    )
  except (OSError, subprocess.TimeoutExpired, UnicodeDecodeError):
    # No ruff on PATH, or a hang: reflow is best-effort, and a width it can
    # guess well enough must never block the edit loop.
    return DEFAULT_LINE_WIDTH
  # `--show-settings` reports settings instead of running the check, so lint
  # violations in the file leave the exit status at zero; a nonzero one means
  # ruff could not resolve the settings at all.
  if result.returncode != 0:
    return DEFAULT_LINE_WIDTH
  setting = _LINE_WIDTH_PATTERN.search(result.stdout)
  return int(setting['width']) if setting else DEFAULT_LINE_WIDTH


def reflow_file(
  path: Path,
  format_comment_markdown: MarkdownFormatter,
  language: Language = Language.PYTHON,
) -> bool:
  """Reflow a source file in place; report whether it changed."""
  try:
    # Read as bytes: read_text's universal-newline translation would flatten
    # \r\n to \n and silently defeat reflow_source's CRLF skip.
    source = path.read_bytes().decode('utf-8')
  except UnicodeDecodeError:
    # Not utf-8 text; nothing here is prose this tool should touch.
    return False
  except OSError:
    # Unreadable file (permissions, or it vanished between the is_file check and
    # here): reflow is best-effort, never a blocker.
    return False
  line_width = _discover_line_width(path)
  try:
    updated = reflow_source(
      source, format_comment_markdown, line_width, language
    )
  except (SyntaxError, tokenize.TokenError, ShellParseError):
    # Mid-turn edits pass through broken states, so a quiet skip is the correct
    # contract here: ruff reports the real Python syntax errors at Stop.
    # ShellParseError also covers an absent shfmt, which likewise leaves the
    # file as the author wrote it.
    #
    # TODO: no automatic check reports a shell parse error; shellcheck catches
    # it but runs by hand. See tasks.md #shell-stop-check
    return False
  if updated == source:
    return False
  try:
    path.write_text(updated, encoding='utf-8')
  except OSError:
    # A read-only target or a full disk must not crash the edit loop; the file
    # simply stays un-reflowed.
    return False
  return True


def _path_from_hook_payload() -> Path | None:
  """Read the edited file's path from the hook JSON payload on stdin."""
  try:
    payload = json.load(sys.stdin)
  except json.JSONDecodeError:
    return None
  if not isinstance(payload, dict):
    return None
  tool_input = payload.get('tool_input')
  if not isinstance(tool_input, dict):
    return None
  file_path = tool_input.get('file_path')
  return Path(file_path) if isinstance(file_path, str) else None


def _language_of(path: Path) -> Language | None:
  """The language to read a path as; None for a file this hook never reflows."""
  if path.suffix == '.py':
    return Language.PYTHON
  if path.suffix in _SHELL_SUFFIXES or path.name in _SHELL_FILENAMES:
    return Language.SHELL
  return None


def main(argv: Sequence[str]) -> int:
  """Reflow the given paths, or the hook payload's path when none are given."""
  paths = [Path(argument) for argument in argv[1:]]
  if not paths:
    payload_path = _path_from_hook_payload()
    paths = [payload_path] if payload_path else []

  # A prettier failure never propagates here: _reflow_chunks degrades to the
  # plain filler, so the hook cannot block the edit loop.
  for path in paths:
    language = _language_of(path)
    if language is None or not path.is_file():
      continue
    reflow_file(path, run_prettier, language)
  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv))
