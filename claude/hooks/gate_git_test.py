#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the git permission gate. Run with the hooks directory on
# PYTHONPATH:
#   PYTHONPATH=~/.claude/hooks pytest ~/.claude/hooks/gate_git_test.py

import io
import json

import gate_git
import pytest
from gate_git import Decision, checkout_discard_warning, evaluate, main

# --- unrecoverable destructive operations are denied ---

# The policy set, written out in full. Each group includes at least one form
# behind an intervening global flag (`-C <path>`, `-c k=v`, `--no-pager`,
# `--git-dir=`), because bypassing the deny via such a flag is the exact gap
# this gate exists to close. The final two entries hide the dangerous operation
# in a later clause of a compound command — it must still be caught.
DENYLISTED: tuple[str, ...] = (
  # Working tree / index — discards uncommitted work (no reflog recovery).
  'git reset --hard',
  'git reset --hard HEAD~2',
  'git -C /tmp/repo reset --hard',  # intervening -C must not bypass
  'git -c core.pager=cat reset --hard',  # intervening -c k=v
  'git --no-pager reset --hard',  # boolean global flag
  'git --git-dir=/r/.git reset --hard',  # =-form global flag
  'git clean -f',
  'git clean -fd',
  'git clean -xf',
  'git -C /repo clean -f',
  'git clean --force',  # --force is the long form of -f
  'git stash drop',
  'git stash clear',
  'git -C /r stash drop',
  'git checkout -f',
  'git checkout --force main',
  'git switch --discard-changes main',
  'git switch -f other',
  'git restore file.txt',  # worktree-discarding (the default mode)
  'git restore .',
  'git restore --worktree src/',
  'git -C /r restore foo',
  'git restore -W file.txt',  # -W (--worktree) discards edits
  'git worktree remove --force /tmp/wt',  # discards the worktree's changes
  # History rewrite that loses refs irreversibly.
  'git branch -D feature',
  'git branch -f main origin/main',
  'git branch -M main',
  'git tag -d v1.0',
  'git tag -f v1.0 HEAD',
  'git update-ref -d refs/heads/dead',
  'git filter-branch --tree-filter true HEAD',
  'git filter-repo --path secret --invert-paths',
  'git reflog expire --expire=now --all',
  'git gc --prune=now',
  'git gc --prune now',  # two-token spelling
  # Remote-destructive — mutates GitHub state, the core threat.
  'git push --force',
  'git push -f origin main',
  'git push --force-with-lease',
  'git push --delete origin feature',
  'git push -d origin feature',
  'git push --mirror',
  'git -C /r push --force',
  'git push origin :feature',  # delete refspec — no flag, but removes a ref
  'git push origin +HEAD:main',  # force refspec — no flag, but overwrites
  'git remote remove origin',
  'git remote rm upstream',
  'git remote -v remove origin',  # a flag before the verb must not bypass
  # Found by traversal — a later compound clause, or inside a substitution;
  # both execute, so neither can smuggle a destructive op past the gate.
  'git status && git reset --hard',
  'echo done; git -C /r clean -fd',
  'echo $(git reset --hard)',
  'result=$(git push --force)',
  'echo `git -C /r clean -f`',
  # An unknown global flag does not suppress the deny scan.
  'git --bogus-flag reset --hard',
)

# --- simple, safe invocations are auto-allowed, including -C forms ---

# status/log/diff/show auto-allow only with safe display/filter flags (an
# unknown flag DEFERs); branch auto-allows only its listing forms. Each
# subcommand appears with a `-C <path>` form, since widening the gate to cover
# `-C` is the feature this enables. The log entry with a dangerous-looking
# *argument* confirms classification keys on the subcommand and flags, not on
# substrings.
ALLOWLISTED: tuple[str, ...] = (
  'git status',
  'git status --short',
  'git -C /tmp/repo status',
  'git -C /tmp/repo/sub status --short',  # path with slashes
  'git --no-pager status',
  'git log',
  'git log --oneline -n 20',
  'git log -p',  # arg-position -p is patch display, not the pager global
  'git log --grep="reset --hard"',  # 'reset --hard' is a quoted log argument
  'git -C /repo log --oneline',
  'git diff',
  'git diff HEAD~1 HEAD',
  'git -C /repo diff --stat',
  'git show',
  'git show HEAD:path/to/file',
  'git -C /repo show abc123',
  'git branch',
  'git branch -a',
  'git -C /repo branch -vv',
)

# --- non-destructive but non-allowlisted commands defer to the prompt ---

# These are neither blocked nor auto-approved: the gate stays silent and lets
# settings.json / the user's prompt decide. Includes the deliberately-permitted
# history rewrites (amend, rebase), the near-miss-but-safe variants of denied
# subcommands (soft reset, dry-run clean, --staged restore), a non-git command
# whose argument merely contains the word 'git', read-only subcommands carrying
# an unsafe option or a config/pager-forcing global (auto-allow declines),
# non-listing branch/worktree forms, and the fail-closed cases the gate can't
# safely auto-allow (an unknown global flag, an unparseable command).
DEFERRED: tuple[str, ...] = (
  'git commit -m "msg"',
  'git commit --amend',  # recoverable rewrite — deliberately not denied
  'git rebase main',  # recoverable rewrite — deliberately not denied
  'git push',  # plain push is neither force nor delete
  'git push origin main',
  'git fetch',
  'git pull',
  'git reset --soft HEAD~1',  # soft reset keeps the working tree
  'git reset HEAD file.txt',  # mixed reset unstages; no data loss
  'git clean -n',  # dry run; without -f it deletes nothing
  'git checkout main',  # plain branch switch; no -f
  'git switch main',
  'git restore --staged file.txt',  # unstage only; no worktree loss
  'git restore -S file.txt',  # -S is the short form of --staged
  'git stash',  # saves work rather than destroying it
  'git stash list',  # read-only, but not on the allow set
  'git stash pop',
  'git add .',
  'git merge feature',
  # Read-only subcommand but with an unsafe option or a config/pager-forcing
  # global, so auto-allow declines (these are not dangerous — they just prompt).
  'git log --output=/tmp/log.txt',  # --output writes a file
  'git diff --ext-diff',  # runs a configured external diff command
  'git status --totally-unknown-flag',  # unknown flag → fail-closed
  'git -p log',  # forced pager can exec core.pager
  'git --paginate show',
  'git -c core.pager=cat log',  # -c injects config
  # branch / worktree forms that are not read-only listing.
  'git branch new-topic',  # creates a ref
  'git branch -m old new',  # rename (non-force; -M would be denied)
  'git worktree list',  # not on the allow set
  'git worktree remove /tmp/wt',  # non-force remove is not hard-denied
  'ls -la',  # not git at all
  'echo git reset --hard',  # 'git' is an argument to echo, not a command
  'git gc --prune=never',  # never-prune destroys nothing
  # Fail-closed: the gate can't safely auto-allow these, so it defers.
  'git --bogus-flag status',  # unknown global flag → fully_recognized False
  'git status "unterminated',  # unparseable → bashlex raises → defer
)

# --- non-simple shapes are never auto-allowed (fail-closed) ---

# Each wraps an otherwise-allowlisted read-only invocation in a shape the gate
# can't fully reason about — a second command, a pipeline, a redirection, or a
# substitution. The safe answer is DEFER (prompt), never ALLOW. The last three
# also confirm the gate does not *deny* on a guess when a word is dynamic: it
# can't know the subcommand, so it defers rather than blocking.
UNSAFE_SHAPES: tuple[str, ...] = (
  'git status && ls',  # compound — a second command rides along
  'git status; git log',
  'git status | grep modified',  # pipeline
  'git -C /r status > /tmp/out.txt',  # redirection
  'git status `whoami`',  # command substitution (backticks)
  'git $SUBCOMMAND',  # parameter expansion — opaque subcommand
  'git -C /r $(echo status)',  # command substitution — opaque subcommand
)


@pytest.mark.parametrize('command', DENYLISTED)
def test_unrecoverable_destructive_operation_is_denied(command: str) -> None:
  """A denylisted operation is blocked, even behind a global flag."""
  assert evaluate(command) is Decision.DENY


@pytest.mark.parametrize('command', ALLOWLISTED)
def test_simple_safe_invocation_is_allowed(command: str) -> None:
  """A single, simple read-only invocation auto-allows, including -C forms."""
  assert evaluate(command) is Decision.ALLOW


@pytest.mark.parametrize('command', DEFERRED)
def test_non_destructive_non_allowlisted_command_defers(command: str) -> None:
  """A command that is neither dangerous nor allowlisted falls through."""
  assert evaluate(command) is Decision.DEFER


@pytest.mark.parametrize('command', UNSAFE_SHAPES)
def test_non_simple_shape_is_never_auto_allowed(command: str) -> None:
  """A read-only invocation in a compound/dynamic shape defers, never allows."""
  assert evaluate(command) is Decision.DEFER


# --- pathspec checkout is not denied, but is flagged with a discard warning ---

# `git checkout <pathspec>` discards uncommitted changes irreversibly, yet
# can't be told apart from a branch switch without repo state — so it is not
# hard-denied; the gate surfaces a warning instead.
CHECKOUT_DISCARDS: tuple[str, ...] = (
  'git checkout -- file.txt',
  'git checkout .',
  'git checkout HEAD -- src/',
  'git -C /repo checkout -- a b',
)

# A branch switch (no pathspec) and non-checkout commands carry no warning.
CHECKOUT_NO_DISCARD: tuple[str, ...] = (
  'git checkout main',
  'git -C /r checkout topic',
  'git switch main',
  'git status',
)


@pytest.mark.parametrize('command', CHECKOUT_DISCARDS)
def test_pathspec_checkout_warns_about_discard(command: str) -> None:
  """A pathspec checkout returns a discard warning."""
  assert checkout_discard_warning(command) is not None


@pytest.mark.parametrize('command', CHECKOUT_NO_DISCARD)
def test_branch_switch_has_no_discard_warning(command: str) -> None:
  """A branch switch or non-checkout command returns no warning."""
  assert checkout_discard_warning(command) is None


# --- fail-closed: bashlex unavailable degrades even a clear deny to a defer ---


def test_defers_when_bashlex_unavailable(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  # With bashlex absent the gate can't parse, so even a clear destructive op
  # degrades to a prompt — the settings.json deny entries are the fallback.
  monkeypatch.setattr(gate_git, '_HAS_BASHLEX', False)
  assert evaluate('git reset --hard') is Decision.DEFER


# --- main() emits the right hook JSON for each decision ---


def _run_gate(command: str) -> str:
  """Run main() on a Bash payload carrying `command`; return its stdout."""
  payload = json.dumps({'tool_input': {'command': command}})
  return _run_gate_on_raw_stdin(payload)


def _run_gate_on_raw_stdin(stdin_text: str) -> str:
  """Run main() on arbitrary raw stdin; return its stdout (for bad payloads)."""
  stdout = io.StringIO()
  main(stdin=io.StringIO(stdin_text), stdout=stdout)
  return stdout.getvalue()


def test_main_emits_deny_with_reason_for_destructive() -> None:
  output = json.loads(_run_gate('git -C /r reset --hard'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'deny'
  assert 'destructive' in output['permissionDecisionReason']


def test_main_emits_allow_without_reason_for_readonly() -> None:
  output = json.loads(_run_gate('git -C /r status'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'allow'
  assert 'permissionDecisionReason' not in output  # an allow carries no reason


def test_main_emits_ask_with_warning_for_pathspec_checkout() -> None:
  output = json.loads(_run_gate('git checkout -- f.txt'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'ask'
  assert 'discard' in output['permissionDecisionReason']


def test_main_emits_nothing_for_deferred_command() -> None:
  assert _run_gate('git commit -m wip') == ''


def test_main_emits_nothing_for_malformed_payload() -> None:
  assert _run_gate_on_raw_stdin('not json at all') == ''


def test_main_emits_nothing_for_non_string_command() -> None:
  assert _run_gate_on_raw_stdin('{"tool_input": {"command": 123}}') == ''
