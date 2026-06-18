#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# PreToolUse(Bash) gate for git: hard-block unrecoverable destructive git
# operations, and auto-allow provably-simple read-only git invocations — both
# regardless of intervening global flags like `-C <path>`.
#
# Threat model
# ------------
# The concern is *unrecoverable* destructive change — operations whose effect
# git's reflog cannot undo — and above all those that mutate the GitHub remote
# state (force-pushes, ref deletions). Local history rewrites that orphan
# commits (amend, rebase) are recoverable via the reflog and are deliberately
# *not* blocked; the genuinely destructive step they enable — publishing the
# rewrite with a force-push — is blocked here instead.
#
# Out of scope: a *malicious repository* that attacks through its own config —
# a `core.pager`, custom diff driver, or textconv that runs code when git
# renders content. This gate assumes the repos it runs in are trusted; defense
# against hostile repo contents is the sandbox's job, not this hook's.
# Auto-allow still refuses the *explicit* exec / file-write flags (`--ext-diff`,
# `--output`, `-c`, a forced `--paginate`); it does not neutralize config that
# fires during ordinary read rendering.
#
# Why this can't live in settings.json
# -------------------------------------
# Bash permission rules in settings.json are literal-prefix matches: a `*` in
# the middle of a pattern is not a wildcard. The discriminating token (the
# subcommand) sits *after* the variable `-C <path>`, so a prefix rule cannot
# express "git, then any -C path, then `reset --hard`". Catching the dangerous
# subcommand behind an intervening flag requires actually parsing the command —
# which is what this hook does, via bashlex.
#
# Fail-closed
# -----------
# The one catastrophic outcome is auto-*allowing* a command that is actually
# dangerous; failing to *deny* one is not catastrophic, because an un-denied
# command is not in the allow set and so still prompts. So ALLOW fires only when
# the whole command is a single, simple git invocation (no operators, pipelines,
# redirections, or substitutions), carries no config-injecting or pager-forcing
# global, and names a read-only subcommand whose every flag is on a curated
# safe-flag allowlist — anything unrecognized DEFERs. On any uncertainty —
# bashlex missing or unable to parse,
# a compound shape, a dynamic word — the gate neither allows nor denies on a
# guess: it DEFERs, letting settings.json and the normal prompt decide.
#
# Intentional redundancy with settings.json
# ------------------------------------------
# settings.json carries bare-form (`git status:*`, `git reset --hard:*`, …)
# allow and deny entries that duplicate part of this hook's policy. This overlap
# is deliberate, not an oversight: those entries are the canonical defaults that
# still apply when this hook DEFERs — most importantly when bashlex is
# unavailable and the hook degrades to a no-op. Keep the two in sync: the
# settings entries are the floor, this hook is the flag-aware extension.

from __future__ import annotations

import enum
import json
import sys
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol, TextIO

# bashlex has no type stubs and may be absent in some runtimes. Guard the import
# so a missing dependency degrades to a no-op gate (every command DEFERs to
# settings.json + the prompt) rather than crashing every Bash call.
try:
  import bashlex
  import bashlex.ast
  import bashlex.errors

  _HAS_BASHLEX = True
except ImportError:
  _HAS_BASHLEX = False


class _Node(Protocol):
  """The bashlex AST attributes this module reads.

  bashlex ships no type stubs, so its nodes arrive untyped (Any). This Protocol
  gives them a typed surface for the few attributes used here, keeping Any out
  of the call graph.

  `parts` and `word` exist only on some node kinds, but they are typed
  non-optional rather than `| None`: where present they are always set (a
  `list`, a `str`); on other kinds the attribute is absent entirely, not None —
  a case `| None` would mismodel. What makes access safe is the `kind` guard
  before every `parts`/`word` use, not a None-check. The cost of this loose
  view is that mypy can't catch an unguarded access (it can't narrow on a
  runtime `kind` value); the guards and tests cover that instead.
  """

  kind: str
  parts: list[_Node]
  word: str


class Decision(enum.Enum):
  """Outcome of classifying a Bash command for the git permission gate."""

  DENY = 'deny'  # hard-block: an unrecoverable destructive git operation
  ALLOW = 'allow'  # auto-approve: a provably simple read-only git invocation
  DEFER = 'defer'  # no decision: fall through to settings.json / the prompt


# git's global options, which precede the subcommand. Value-taking ones consume
# the following token (`-C <path>`), so the subcommand scan must skip two; the
# `--opt=value` spelling is a single token. Boolean ones consume only
# themselves. An unrecognized leading flag is treated as boolean for the deny
# scan but blocks the allow path (see _parse_invocation).
GLOBAL_VALUE_OPTIONS = frozenset(
  {
    '-C',
    '-c',
    '--attr-source',
    '--config-env',
    '--git-dir',
    '--work-tree',
    '--namespace',
    '--exec-path',
    '--super-prefix',
  }
)
GLOBAL_BOOLEAN_OPTIONS = frozenset(
  {
    '--no-pager',
    '--paginate',
    '-p',
    '--bare',
    '--no-replace-objects',
    '--literal-pathspecs',
    '--glob-pathspecs',
    '--noglob-pathspecs',
    '--icase-pathspecs',
    '--no-optional-locks',
    '--no-lazy-fetch',
  }
)

# Subcommands whose output is read-only in every form we auto-allow. branch is
# handled separately (SAFE_BRANCH_FLAGS) because a bare operand creates a ref.
READ_ONLY_SUBCOMMANDS = frozenset({'status', 'log', 'diff', 'show'})

# Global flags that, even before a read-only subcommand, can run arbitrary code
# or inject config: `-c`/`--config-env` set config (pager, alias, diff driver),
# `--exec-path` redirects where git resolves its programs (and is prepended to
# PATH), and `-p`/`--paginate` force the pager. Their presence blocks auto-allow.
ALLOW_BLOCKING_GLOBALS = frozenset(
  {'-c', '--config-env', '--exec-path', '-p', '--paginate'}
)

# Flags safe to auto-allow on a read-only subcommand: display and filtering
# options only. This is an allowlist by design — an unrecognized flag DEFERs
# (fail-closed), so an omission costs a prompt, never safety. Deliberately
# absent are the write/exec options (`--output`, `--ext-diff`, `--textconv`,
# `-O`, …). A value-taking flag needs only its name here: a `--flag value` value
# is a non-dash operand (harmless on these subcommands) and `--flag=value` is
# checked by the name before the `=`.
SAFE_READ_FLAGS = frozenset(
  {
    # status
    '-s',
    '--short',
    '-b',
    '--branch',
    '--porcelain',
    '--long',
    '-z',
    '-u',
    '--untracked-files',
    '--ignored',
    '--ahead-behind',
    # log/show selection and ordering
    '--oneline',
    '--graph',
    '--decorate',
    '--no-decorate',
    '--abbrev-commit',
    '--no-abbrev-commit',
    '--pretty',
    '--format',
    '--date',
    '--abbrev',
    '-n',
    '--max-count',
    '--skip',
    '--reverse',
    '--first-parent',
    '--merges',
    '--no-merges',
    '--all',
    '--source',
    '--topo-order',
    '--date-order',
    '--follow',
    '--full-history',
    # log filtering
    '--since',
    '--after',
    '--until',
    '--before',
    '--author',
    '--committer',
    '--grep',
    '--all-match',
    '--invert-grep',
    '-i',
    '--regexp-ignore-case',
    '-E',
    '--extended-regexp',
    '-F',
    '--fixed-strings',
    '-S',
    '-G',
    # diff / patch display (content rendering is in scope per the threat model)
    '-p',
    '--patch',
    '--no-patch',
    '--stat',
    '--shortstat',
    '--numstat',
    '--summary',
    '--name-only',
    '--name-status',
    '--raw',
    '-U',
    '--unified',
    '--cached',
    '--staged',
    '-M',
    '--find-renames',
    '-C',
    '--find-copies',
    '-w',
    '--ignore-all-space',
    '--ignore-space-change',
    '--ignore-blank-lines',
    '--diff-filter',
    '--color',
    '--no-color',
    '--word-diff',
    '--color-words',
    '-R',
  }
)

# The value-less short flags from SAFE_READ_FLAGS, as bare letters, so a
# clustered short-flag token (`-sb`) auto-allows when every letter is one of
# these. Each is a display- or filter-only toggle whose output is read-only —
# none writes a file, runs a program, or mutates state:
#   s  status: short format
#   b  status: show branch
#   z  status: NUL-terminated records
#   p  log/diff/show: show the patch (content display)
#   w  diff: ignore all whitespace
#   i  log: case-insensitive --grep
#   E  log: extended-regexp --grep
#   F  log: fixed-string --grep
#   R  diff: reverse the diff
# Value-taking short flags (`-n`, `-U`, `-S`, `-G`, `-C`, `-M`) are excluded:
# once one appears in a cluster the remaining characters are its value, not more
# flags, so such a cluster cannot be validated letter-by-letter.
SAFE_READ_BOOLEAN_SHORT_FLAGS = frozenset('sbzpwiEFR')

# Read-only `git branch` listing flags. branch auto-allows only when *every*
# argument is one of these — any operand (a branch to create or rename) or any
# other flag (`-d`/`-m`/`-u`/…) falls through to a prompt instead.
SAFE_BRANCH_FLAGS = frozenset(
  {
    '-a',
    '--all',
    '-r',
    '--remotes',
    '-v',
    '-vv',
    '--verbose',
    '-l',
    '--list',
    '--show-current',
    '--color',
    '--no-color',
    '--column',
    '--no-column',
    '-q',
    '--quiet',
  }
)

DENY_REASON = (
  'Blocked by the git gate: this is an irreversibly destructive operation — it '
  'discards uncommitted work, rewrites history beyond reflog recovery, or '
  'mutates remote state. Nothing recovers it. If you truly intend it, run it '
  'yourself outside the agent.'
)

# Surfaced (as an "ask") for `git checkout <pathspec>`, which is not hard-denied
# — see the comment on _is_dangerous's checkout handling.
DISCARD_WARNING = (
  'Heads up: `git checkout` with a pathspec (`-- <path>`, or `.`) discards '
  'uncommitted changes to those files, and that cannot be recovered. It is not '
  'auto-blocked because a pathspec checkout is hard to tell apart from a '
  'branch switch — confirm you mean to discard before approving.'
)


@dataclass(frozen=True)
class GitInvocation:
  """A single `git` command, split into subcommand and its arguments.

  `fully_recognized` is False when an unrecognized global flag appeared before
  the subcommand; the allow path requires it True so an unknown value-taking
  flag can never cause a misread subcommand to be auto-approved.
  `has_blocking_global` is True when a config-injecting or pager-forcing global
  (`-c`/`--config-env`/`-p`/`--paginate`) appeared; the allow path refuses it.
  """

  subcommand: str
  args: tuple[str, ...]
  fully_recognized: bool
  has_blocking_global: bool


def _safe_parse(command: str) -> Sequence[_Node] | None:
  """Parse a command into bashlex trees; None if it can't be parsed safely.

  Returns None when bashlex is unavailable or the command is syntactically
  unparseable — both are "uncertain", which the caller treats as DEFER.
  """
  if not _HAS_BASHLEX:
    return None
  try:
    # bashlex.parse is untyped (Any); bind it to a typed name so this function
    # returns a typed value instead of leaking Any to every caller.
    trees: list[_Node] = bashlex.parse(command)
  except (bashlex.errors.ParsingError, NotImplementedError):
    # ParsingError also covers tokenizer failures (unmatched quotes, an
    # unclosed `$(`) which subclass it; NotImplementedError covers a construct
    # bashlex doesn't model. All are "uncertain" → DEFER.
    return None
  return trees


def _iter_nodes(node: _Node) -> Iterator[_Node]:
  """Yield a node and every descendant, recursing through all child attributes.

  This walks into command-substitution bodies too, so a dangerous git call
  hidden inside `$(...)` — which would actually execute — is still seen.
  """
  yield node
  for value in vars(node).values():
    if isinstance(value, bashlex.ast.node):
      yield from _iter_nodes(value)
    elif isinstance(value, list):
      for item in value:
        if isinstance(item, bashlex.ast.node):
          yield from _iter_nodes(item)


def _command_nodes(
  trees: Sequence[_Node],
) -> Sequence[_Node]:
  """Every command node anywhere in the parsed command(s)."""
  return [
    node
    for tree in trees
    for node in _iter_nodes(tree)
    if node.kind == 'command'
  ]


def _words_of(command_node: _Node) -> Sequence[str]:
  """The literal words of a command node, ignoring redirects."""
  return [part.word for part in command_node.parts if part.kind == 'word']


def _parse_invocation(words: Sequence[str]) -> GitInvocation | None:
  """Split a `git ...` word list into subcommand + args, skipping globals.

  Assumes words[0] is the git program. Returns None if no subcommand follows
  the global options.
  """
  index = 1  # past the `git` program word
  fully_recognized = True
  has_blocking_global = False
  while index < len(words):
    token = words[index]
    if token.split('=', 1)[0] in ALLOW_BLOCKING_GLOBALS:
      has_blocking_global = True
    if token in GLOBAL_VALUE_OPTIONS:
      index += 2  # the flag plus its value (e.g. `-C <path>`)
    elif '=' in token and token.split('=', 1)[0] in GLOBAL_VALUE_OPTIONS:
      index += 1  # the `--opt=value` spelling is one token
    elif token in GLOBAL_BOOLEAN_OPTIONS:
      index += 1
    elif token.startswith('-'):
      # An unknown global flag: keep scanning for the deny path, but mark the
      # parse unrecognized so the allow path declines to auto-approve.
      fully_recognized = False
      index += 1
    else:
      return GitInvocation(
        subcommand=token,
        args=tuple(words[index + 1 :]),
        fully_recognized=fully_recognized,
        has_blocking_global=has_blocking_global,
      )
  return None


def _git_invocation_of(command_node: _Node) -> GitInvocation | None:
  """The GitInvocation for a command node, or None if it isn't a git call."""
  words = _words_of(command_node)
  if not words or Path(words[0]).name != 'git':
    return None
  return _parse_invocation(words)


def _has_short_flag(args: Sequence[str], letters: str) -> bool:
  """Whether any short-flag cluster in `args` contains one of `letters`.

  git accepts clustered short flags (`-fd` is `-f -d`), so a destructive flag
  can hide inside a bundle that exact-token matching would miss. Letters are
  case-sensitive — `-D` (force-delete a branch) differs from `-d`. A rare
  over-match is possible when a value-taking short flag's value happens to
  contain a letter (e.g. `clean -e <pattern>`); that only ever over-denies,
  which is fail-safe.
  """
  return any(
    arg.startswith('-')
    and not arg.startswith('--')
    and any(letter in arg[1:] for letter in letters)
    for arg in args
  )


def _restore_discards_worktree(args: Sequence[str]) -> bool:
  """Whether a `git restore` touches the working tree (discarding edits).

  restore writes the working tree by default; only a staged-only restore
  (`--staged`/`-S` without `--worktree`/`-W`) leaves the working tree alone.
  """
  restores_staged = '--staged' in args or '-S' in args
  restores_worktree = '--worktree' in args or '-W' in args
  staged_only = restores_staged and not restores_worktree
  return not staged_only


def _gc_prunes_now(args: Sequence[str]) -> bool:
  """Whether a `git gc` immediately prunes unreachable objects."""
  for index, arg in enumerate(args):
    if arg.startswith('--prune=') and not arg.endswith('=never'):
      return True
    # The two-token spelling `--prune <date>` (anything but `never`).
    if (
      arg == '--prune' and index + 1 < len(args) and args[index + 1] != 'never'
    ):
      return True
  return False


def _push_is_destructive(args: Sequence[str]) -> bool:
  """Whether a `git push` rewrites or deletes remote refs."""
  # Flags that rewrite or delete remote refs: `--force` (incl. -with-lease and
  # -if-*), `--delete`, `--mirror`, `--prune`, and a force (-f) or delete (-d)
  # hidden in a short-flag cluster like `-fd`.
  if (
    any(arg.startswith('--force') for arg in args)
    or '--delete' in args
    or '--mirror' in args
    or '--prune' in args
    or _has_short_flag(args, 'fd')
  ):
    return True
  # A positional refspec also rewrites refs: `:dst` deletes, `+...` force-
  # updates (including the colon-less shorthand `+branch`). Skip the value of a
  # value-taking flag so e.g. `--push-option +rebase` is not read as a refspec.
  value_flags = {'-o', '--push-option', '--receive-pack', '--exec', '--repo'}
  skip_next = False
  for arg in args:
    if skip_next:
      skip_next = False
      continue
    if arg in value_flags:
      skip_next = True
      continue
    if arg.startswith(':') or arg.startswith('+'):
      return True
  return False


def _subcommand_verb(args: Sequence[str]) -> str | None:
  """The first non-flag argument — a subcommand's own verb (drop, remove, …).

  Used for two-level subcommands (stash/reflog/remote/worktree) so a flag before
  the verb (`git remote -v remove`) can't shift it out of view, and a flag's
  value (`git stash push -m drop`) is not mistaken for the verb.
  """
  for arg in args:
    if not arg.startswith('-'):
      return arg
  return None


def _is_dangerous(invocation: GitInvocation) -> bool:
  """Whether the invocation is an unrecoverable destructive operation."""
  subcommand = invocation.subcommand
  args = invocation.args

  # Working tree / index — discards uncommitted work (no reflog recovery).
  if subcommand == 'reset':
    return '--hard' in args
  if subcommand == 'clean':
    return _has_short_flag(args, 'f') or '--force' in args
  if subcommand == 'stash':
    return _subcommand_verb(args) in {'drop', 'clear'}
  if subcommand == 'checkout':
    # Only the force form is hard-denied. A pathspec checkout
    # (`git checkout -- <path>` / `git checkout .`) also discards uncommitted
    # changes, but it cannot be reliably told apart from a branch switch
    # without repo state, so it is deferred-with-a-warning rather than blocked
    # on a guess — see _pathspec_checkout_warning and DISCARD_WARNING.
    return _has_short_flag(args, 'f') or '--force' in args
  if subcommand == 'switch':
    return (
      _has_short_flag(args, 'f')
      or '--force' in args
      or '--discard-changes' in args
    )
  if subcommand == 'restore':
    return _restore_discards_worktree(args)
  if subcommand == 'worktree':
    # `worktree remove --force` deletes a linked worktree along with its
    # uncommitted changes; non-force remove refuses on a dirty worktree.
    return _subcommand_verb(args) == 'remove' and (
      '-f' in args or '--force' in args
    )

  # History rewrite that loses refs irreversibly.
  if subcommand == 'branch':
    # -D force-deletes, -M force-renames, -f forces; lowercase -d/-m are the
    # safe (merged-only delete, non-force rename) forms and stay out.
    return _has_short_flag(args, 'DMf') or '--force' in args
  if subcommand == 'tag':
    return (
      _has_short_flag(args, 'df') or '--delete' in args or '--force' in args
    )
  if subcommand == 'update-ref':
    # --stdin feeds a batch of ref updates/deletes the parser cannot see.
    return '-d' in args or '--delete' in args or '--stdin' in args
  if subcommand in {'filter-branch', 'filter-repo'}:
    return True
  if subcommand == 'reflog':
    # expire bulk-prunes entries; delete drops specific ones — both shrink the
    # reflog safety net that keeps other rewrites recoverable.
    return _subcommand_verb(args) in {'expire', 'delete'}
  if subcommand == 'gc':
    return _gc_prunes_now(args)
  if subcommand == 'prune':
    # `git prune` removes unreachable objects immediately; -n/--dry-run lists.
    return '-n' not in args and '--dry-run' not in args

  # Remote-destructive — mutates GitHub state, the core threat.
  if subcommand == 'push':
    return _push_is_destructive(args)
  if subcommand == 'remote':
    return _subcommand_verb(args) in {'remove', 'rm'}

  return False


def _is_plain_command(node: _Node) -> bool:
  """Whether a tree is a single command of only static words (no operators).

  Excludes anything the allow path can't fully reason about: a non-command top
  node (a list/pipeline has operators), a redirection, or a dynamic word
  (substitution/expansion produces a non-empty `.parts`).
  """
  if node.kind != 'command':
    return False
  for part in node.parts:
    if part.kind != 'word':
      return False  # a redirect, etc.
    if part.parts:
      return False  # a substitution or expansion — opaque
  return True


def _is_safe_read_arg(arg: str) -> bool:
  """Whether an argument to a read-only subcommand is safe to auto-allow.

  Operands (refs, paths) are harmless on a read-only subcommand; a flag is safe
  only if it is on SAFE_READ_FLAGS. The `--flag=value` form is keyed on the
  name. A clustered short-flag token (`-sb`) is safe when every letter is a
  value-less read flag — git treats `-sb` as `-s -b`, so matching the whole
  token against SAFE_READ_FLAGS alone would needlessly prompt for it. The deny
  path already decomposes clusters (_has_short_flag); this keeps the allow path
  symmetric.
  """
  if not arg.startswith('-'):
    return True
  if arg.split('=', 1)[0] in SAFE_READ_FLAGS:
    return True
  # A clustered short-flag token: a single dash, then letters, no `=` value. A
  # value-taking flag can't appear (it would consume the rest as its value), so
  # every letter must be on the value-less safe set.
  if arg.startswith('--') or '=' in arg:
    return False
  return all(letter in SAFE_READ_BOOLEAN_SHORT_FLAGS for letter in arg[1:])


def _is_auto_allowable(invocation: GitInvocation) -> bool:
  """Whether a single git invocation is safe to auto-approve without a prompt.

  Requires fully-recognized globals with none that inject config or force a
  pager, a read-only subcommand, and only safe flags — branch additionally
  permits no operand, since a bare operand would create or rename a ref.
  """
  if not invocation.fully_recognized or invocation.has_blocking_global:
    return False
  if invocation.subcommand == 'branch':
    return all(arg in SAFE_BRANCH_FLAGS for arg in invocation.args)
  if invocation.subcommand in READ_ONLY_SUBCOMMANDS:
    return all(_is_safe_read_arg(arg) for arg in invocation.args)
  return False


def _classify(trees: Sequence[_Node]) -> Decision:
  """Classify already-parsed command trees into a gate Decision.

  DENY if any git call (including inside a substitution) is destructive; ALLOW
  if the whole command is one plain auto-allowable git call; else DEFER.
  """
  # Deny scan first — deny takes precedence, and it covers every git call,
  # even one hidden in a later compound clause or a substitution.
  for node in _command_nodes(trees):
    invocation = _git_invocation_of(node)
    if invocation is not None and _is_dangerous(invocation):
      return Decision.DENY

  # Allow only the simplest provable shape: one plain command whose globals,
  # subcommand, and flags are all known-safe (see _is_auto_allowable). (Not
  # dangerous is already guaranteed by the deny scan above.)
  if len(trees) == 1 and _is_plain_command(trees[0]):
    invocation = _git_invocation_of(trees[0])
    if invocation is not None and _is_auto_allowable(invocation):
      return Decision.ALLOW

  return Decision.DEFER


def _pathspec_checkout_warning(trees: Sequence[_Node]) -> str | None:
  """A discard warning if parsed trees contain a pathspec `git checkout`."""
  for node in _command_nodes(trees):
    invocation = _git_invocation_of(node)
    if (
      invocation is not None
      and invocation.subcommand == 'checkout'
      and not _is_dangerous(invocation)
      and ('--' in invocation.args or '.' in invocation.args)
    ):
      return DISCARD_WARNING
  return None


def _emit(
  stdout: TextIO, permission_decision: str, reason: str | None = None
) -> None:
  """Write a PreToolUse permission decision as JSON to the given stream."""
  hook_output: dict[str, str] = {
    'hookEventName': 'PreToolUse',
    'permissionDecision': permission_decision,
  }
  if reason is not None:
    hook_output['permissionDecisionReason'] = reason
  json.dump({'hookSpecificOutput': hook_output}, stdout, ensure_ascii=False)


def main(stdin: TextIO = sys.stdin, stdout: TextIO = sys.stdout) -> None:
  """Read the hook payload from `stdin` and emit the decision to `stdout`.

  Emits nothing for DEFER (no destructive op, not auto-allowable) so the call
  falls through to settings.json and the normal prompt — except a deferred
  pathspec checkout, which is surfaced as an "ask" carrying the discard warning.
  The streams are parameters so the decision flow can be tested in memory.
  """
  try:
    payload = json.load(stdin)
  except json.JSONDecodeError:
    return  # unparseable payload: emit no decision (DEFER)

  tool_input = payload.get('tool_input') if isinstance(payload, dict) else None
  command = tool_input.get('command') if isinstance(tool_input, dict) else None
  if not isinstance(command, str):
    return

  # Parse once and reuse the trees for both the decision and the discard
  # warning, rather than parsing for each — this runs on every Bash call.
  trees = _safe_parse(command) if 'git' in command else None
  decision = _classify(trees) if trees is not None else Decision.DEFER
  if decision is Decision.DENY:
    _emit(stdout, 'deny', DENY_REASON)
  elif decision is Decision.ALLOW:
    _emit(stdout, 'allow')
  elif trees is not None and 'checkout' in command:
    warning = _pathspec_checkout_warning(trees)
    if warning is not None:
      _emit(stdout, 'ask', warning)


if __name__ == '__main__':
  main()
