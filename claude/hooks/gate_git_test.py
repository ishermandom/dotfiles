#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for the git permission gate, exercised through its only public
# entry point — main() reading a hook payload from stdin and writing a decision
# to stdout. Run with the hooks directory on PYTHONPATH:
#   PYTHONPATH=~/.claude/hooks pytest ~/.claude/hooks/gate_git_test.py

import io
import json

import gate_git
import pytest

# --- helpers: drive the gate through its main() entry point ---


def _run_gate_on_raw_stdin(stdin_text: str) -> str:
  """main()'s stdout for arbitrary raw stdin (for malformed-payload tests)."""
  stdout = io.StringIO()
  gate_git.main(stdin=io.StringIO(stdin_text), stdout=stdout)
  return stdout.getvalue()


def _run_gate(command: str) -> str:
  """main()'s stdout for a Bash payload carrying `command`."""
  return _run_gate_on_raw_stdin(
    json.dumps({'tool_input': {'command': command}})
  )


def _decision_for(command: str) -> str | None:
  """The permissionDecision main() emits for `command`.

  None when main() emits nothing — a plain DEFER that falls through to
  settings.json and the prompt.
  """
  raw = _run_gate(command)
  if not raw:
    return None
  decision = json.loads(raw)['hookSpecificOutput']['permissionDecision']
  assert isinstance(decision, str)
  return decision


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
  'git --attr-source HEAD reset --hard',  # value-taking global must not bypass
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
  'git branch -Dv feature',  # bundled: -D (force-delete) inside a cluster
  'git tag -d v1.0',
  'git tag -f v1.0 HEAD',
  'git tag -df v1.0',  # bundled tag delete/force
  'git update-ref -d refs/heads/dead',
  'git update-ref --stdin',  # batch ref mutation; payload invisible to parser
  'git filter-branch --tree-filter true HEAD',
  'git filter-repo --path secret --invert-paths',
  'git reflog expire --expire=now --all',
  "git reflog delete 'HEAD@{0}'",  # delete drops a specific reflog entry
  'git gc --prune=now',
  'git gc --prune now',  # two-token spelling
  'git prune',  # removes unreachable objects immediately
  # Remote-destructive — mutates GitHub state, the core threat.
  'git push --force',
  'git push -f origin main',
  'git push --force-with-lease',
  'git push --delete origin feature',
  'git push -d origin feature',
  'git push -fd origin main',  # bundled short flags hide -f (force) / -d
  'git push --mirror',
  'git push --prune origin main',  # deletes remote refs with no local match
  'git -C /r push --force',
  'git push origin :feature',  # delete refspec — no flag, but removes a ref
  'git push origin +HEAD:main',  # force refspec — no flag, but overwrites
  'git push origin +main',  # colon-less force-push shorthand
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
  'git status -sb',  # clustered short flags (-s -b) auto-allow
  'git -C /tmp/repo status -sb',  # ...even behind an intervening -C
  'git diff -Rw',  # clustered diff toggles (-R reverse, -w ignore-space)
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
  'git push -u origin main',  # -u (set-upstream) is not destructive
  'git push --push-option +rebase origin main',  # value, not a force refspec
  'git fetch',
  'git pull',
  'git reset --soft HEAD~1',  # soft reset keeps the working tree
  'git reset HEAD file.txt',  # mixed reset unstages; no data loss
  'git clean -n',  # dry run; without -f it deletes nothing
  'git prune --dry-run',  # dry run only lists; never removes objects
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
  'git status -sx',  # unknown letter in a short-flag cluster → fail-closed
  'git log -pS',  # -S (pickaxe) takes a value, so the cluster can't be split
  'git -p log',  # forced pager can exec core.pager
  'git --paginate show',
  'git -c core.pager=cat log',  # -c injects config
  'git --exec-path=/opt/git-core status',  # exec-path redirect blocks allow
  # branch / worktree forms that are not read-only listing.
  'git branch new-topic',  # creates a ref
  'git branch -m old new',  # rename (non-force; -M would be denied)
  'git branch -d merged',  # lowercase -d (merged-only delete) is not -D
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
  assert _decision_for(command) == 'deny'


@pytest.mark.parametrize('command', ALLOWLISTED)
def test_simple_safe_invocation_is_allowed(command: str) -> None:
  """A single, simple read-only invocation auto-allows, including -C forms."""
  assert _decision_for(command) == 'allow'


@pytest.mark.parametrize('command', DEFERRED)
def test_non_destructive_non_allowlisted_command_defers(command: str) -> None:
  """A command that is neither dangerous nor allowlisted emits no decision."""
  assert _decision_for(command) is None


@pytest.mark.parametrize('command', UNSAFE_SHAPES)
def test_non_simple_shape_is_never_auto_allowed(command: str) -> None:
  """A read-only invocation in a compound/dynamic shape defers, never allows."""
  assert _decision_for(command) is None


# --- pathspec checkout is not denied, but is flagged with a discard warning ---

# `git checkout <pathspec>` discards uncommitted changes irreversibly, yet
# can't be told apart from a branch switch without repo state — so it is not
# hard-denied; the gate surfaces a warning by turning it into an "ask".
CHECKOUT_DISCARDS: tuple[str, ...] = (
  'git checkout -- file.txt',
  'git checkout .',
  'git checkout HEAD -- src/',
  'git -C /repo checkout -- a b',
)

# A branch switch (no pathspec) defers without a discard warning.
CHECKOUT_NO_DISCARD: tuple[str, ...] = (
  'git checkout main',
  'git -C /r checkout topic',
  'git switch main',
)


@pytest.mark.parametrize('command', CHECKOUT_DISCARDS)
def test_pathspec_checkout_is_asked_with_discard_warning(command: str) -> None:
  """A pathspec checkout defers to an 'ask' (which carries the warning)."""
  assert _decision_for(command) == 'ask'


@pytest.mark.parametrize('command', CHECKOUT_NO_DISCARD)
def test_branch_switch_defers_without_a_discard_warning(command: str) -> None:
  """A branch switch (no pathspec) defers silently — no discard 'ask'."""
  assert _decision_for(command) is None


# --- fail-closed: bashlex unavailable degrades even a clear deny to a defer ---


def test_defers_when_bashlex_unavailable(
  monkeypatch: pytest.MonkeyPatch,
) -> None:
  # With bashlex absent the gate can't parse, so even a clear destructive op
  # degrades to a prompt — the settings.json deny entries are the fallback.
  monkeypatch.setattr(gate_git, '_HAS_BASHLEX', False)
  assert _decision_for('git reset --hard') is None


# --- main()'s emitted JSON carries the right shape and reason for each path ---


def test_deny_carries_a_reason() -> None:
  output = json.loads(_run_gate('git -C /r reset --hard'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'deny'
  assert 'destructive' in output['permissionDecisionReason']


def test_allow_carries_no_reason() -> None:
  output = json.loads(_run_gate('git -C /r status'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'allow'
  assert 'permissionDecisionReason' not in output  # an allow carries no reason


def test_ask_carries_the_discard_warning() -> None:
  output = json.loads(_run_gate('git checkout -- f.txt'))['hookSpecificOutput']
  assert output['permissionDecision'] == 'ask'
  assert 'discard' in output['permissionDecisionReason']


def test_malformed_payload_emits_nothing() -> None:
  assert _run_gate_on_raw_stdin('not json at all') == ''


def test_non_string_command_emits_nothing() -> None:
  assert _run_gate_on_raw_stdin('{"tool_input": {"command": 123}}') == ''
