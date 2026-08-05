#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
"""Fire this checkout's hooks without installing them.

A worktree's hooks are never the ones a session runs: `~/.claude` symlinks to
the main checkout, so every session on the machine runs the main checkout's copy
whatever the worktree holds. Installing a worktree's copy to watch it fire would
hand every concurrent session an unreviewed hook. This script runs a throwaway
session that loads this checkout's hooks and none of the installed ones, so a
hook fires for real against the harness's own payload while every other session
keeps running the config it already had.

Usage: `probe_worktree_hooks.py [claude-option...] <prompt>`

The prompt has to provoke the tool call the hook matches on — for a PostToolUse
Edit|Write hook, something like "Use the Write tool to create probe.md
containing hello". Options given before the prompt reach `claude` unchanged;
`--permission-mode` defaults to `acceptEdits` so that a prompt of that shape
runs unattended. An option whose value is optional swallows the prompt —
`--debug "say hi"` reads the prompt as the debug filter, and claude then reports
no prompt at all — so pass such an option its value explicitly. Name a path
inside the worktree, since the probe session declines to write outside its own
workspace, and delete what it creates once the probe is done: an uncommitted
file left behind keeps the automatic worktree cleanups from ever reaping the
worktree.

Three limits worth knowing:

- Only the hook commands move, so whether a probe reaches a script the hook
  calls depends on how the hook names that script. A path through
  `$HOME/.claude/scripts/` still resolves to the installed copy — run those
  scripts out of the worktree directly instead, since they are plain scripts
  rather than hooks. A path the hook resolves against its own location travels
  with the hook: `stop_checks.sh` finds its steps through `${BASH_SOURCE[0]}`,
  so a probe does fire the worktree's `format.sh` — over the installed
  `quiet-*.sh` runners that `format.sh` in turn names through
  `$HOME/.claude/scripts/`.
- A probe writes to shared state. The logging hooks resolve their own
  destinations under `~/.claude/logs/`, so a probe appends there and to the
  session token accounting as though it were real work.
- The probe session runs the whole hook set, Stop hooks included, so it costs a
  model turn plus the test and format chain every time.
"""

import json
import subprocess
import sys
import tempfile
from collections.abc import (
  Callable,
  Iterator,
  Mapping,
  MutableMapping,
  Sequence,
)
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO, TypeVar

SCRIPT_NAME = Path(__file__).name

# The prefix every hook command in settings.json is written with. It resolves to
# the installed config however the checkout holding it is reached.
INSTALLED_PREFIX = '~/.claude/'

Expected = TypeVar('Expected')


class MalformedSettingsError(Exception):
  """Raised when a settings file's `hooks` section is not shaped as expected."""


@dataclass(frozen=True)
class ProbeArguments:
  """A caller's `claude` options, split from the prompt they end with."""

  options: tuple[str, ...]
  prompt: str


def _require(
  value: object, expected: type[Expected], location: str, shape: str
) -> Expected:
  """Return `value` as `expected`, or say where the settings shape broke."""
  if not isinstance(value, expected):
    raise MalformedSettingsError(
      f'{location} holds {type(value).__name__}, expected {shape}'
    )
  return value


def hook_entries(
  settings: Mapping[str, object],
) -> Iterator[MutableMapping[str, object]]:
  """Yield every hook entry in `settings`, across all events and matchers.

  The `hooks` section nests three levels deep — an event name, the matcher
  groups registered for that event, then the hooks each group runs:

  ```json
  "hooks": {
    "PostToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"command": "..."}]}
    ]
  }
  ```

  A level holding something else raises rather than being skipped: a skipped
  hook would keep its installed path and quietly point the probe back at the
  installed copy — the one outcome this script exists to avoid.
  """
  events = _require(
    settings.get('hooks', {}), dict, '"hooks"', 'an object of event names'
  )
  for event_name, event_groups in events.items():
    event = f'"hooks.{event_name}"'
    groups = _require(event_groups, list, event, 'a list of matcher groups')
    for index, group in enumerate(groups):
      location = f'matcher group {index} of {event}'
      matcher_group = _require(group, dict, location, 'an object')
      hooks = _require(
        matcher_group.get('hooks', []),
        list,
        f'the hooks of {location}',
        'a list',
      )
      for hook in hooks:
        yield _require(hook, dict, f'a hook in {location}', 'an object')


def redirect_hook_commands(
  settings: Mapping[str, object], checkout_claude_dir: Path
) -> None:
  """Point every hook command in `settings` at this checkout, in place.

  A command can name its script anywhere in the line — bare, behind an
  interpreter such as `python3`, or twice in a chain — so every `~/.claude/` in
  it moves rather than only a leading one. One left behind would run the
  installed copy and report a passing probe for a hook this checkout never
  fired.

  Only hook commands move. A `permissions` entry naming a `~/.claude` path has
  to keep matching a command written that same way, so rewriting it would
  quietly narrow what the probe session is allowed to run.
  """
  for entry in hook_entries(settings):
    command = entry.get('command')
    if isinstance(command, str):
      entry['command'] = command.replace(
        INSTALLED_PREFIX, f'{checkout_claude_dir}/'
      )


def split_arguments(arguments: Sequence[str]) -> ProbeArguments:
  """Split the trailing prompt from the `claude` options ahead of it."""
  return ProbeArguments(options=tuple(arguments[:-1]), prompt=arguments[-1])


def names_permission_mode(options: Sequence[str]) -> bool:
  """Report whether the caller already chose a permission mode.

  Covers both spellings a caller can use, since the command-line parser accepts
  an option's value as a separate argument or joined by `=`.
  """
  return any(
    option == '--permission-mode' or option.startswith('--permission-mode=')
    for option in options
  )


def build_claude_command(
  settings_path: Path, probe: ProbeArguments
) -> Sequence[str]:
  """Assemble the `claude` invocation that runs the probe.

  `--setting-sources` omits `user`, the source the installed hooks load from,
  while `--settings` is a separate channel — so the rewritten file still takes
  effect.
  """
  command = [
    'claude',
    '-p',
    '--settings',
    str(settings_path),
    '--setting-sources',
    'project',
  ]
  # A prompt that provokes an edit needs a permission mode to run unattended,
  # but a probe of a Bash gate wants a different one.
  if not names_permission_mode(probe.options):
    command += ['--permission-mode', 'acceptEdits']
  command += probe.options
  command.append(probe.prompt)
  return command


def main(
  arguments: Sequence[str],
  checkout_root: Path | None,
  run_command: Callable[[Sequence[str]], int] = subprocess.call,
  stderr: TextIO = sys.stderr,
) -> int:
  """Probe `checkout_root`'s hooks with `arguments`, returning an exit code."""
  # The prompt is the final argument, so a trailing option means none was given.
  # An argument list ending in an option's *value* reads no differently from one
  # ending in a prompt, so claude reports that case itself.
  if not arguments or arguments[-1].startswith('-'):
    print(f'usage: {SCRIPT_NAME} [claude-option...] <prompt>', file=stderr)
    return 2
  if not checkout_root:
    print(
      f'{SCRIPT_NAME}: run this from inside a checkout of the config repo',
      file=stderr,
    )
    return 1

  settings_path = checkout_root / 'claude' / 'settings.json'
  if not settings_path.is_file():
    print(
      f'{SCRIPT_NAME}: no settings to probe at {settings_path}', file=stderr
    )
    return 1

  try:
    settings: object = json.loads(settings_path.read_text())
  except json.JSONDecodeError as error:
    # Settings that no longer parse are the likeliest state to probe from, since
    # the file is usually mid-edit; starting a session on them would load no
    # hooks at all and read as the hook under test never firing.
    print(f'{SCRIPT_NAME}: cannot read {settings_path}: {error}', file=stderr)
    return 1
  if not isinstance(settings, dict):
    print(
      f'{SCRIPT_NAME}: {settings_path} does not hold an object', file=stderr
    )
    return 1

  try:
    redirect_hook_commands(settings, checkout_root / 'claude')
  except MalformedSettingsError as error:
    print(f'{SCRIPT_NAME}: {settings_path} is malformed: {error}', file=stderr)
    return 1

  # delete=True removes the rewritten settings when the block exits, however the
  # probe session ended.
  with tempfile.NamedTemporaryFile(
    mode='w', suffix='.json', prefix='probe-worktree-hooks.', delete=True
  ) as probe_settings:
    json.dump(settings, probe_settings)
    probe_settings.flush()
    probe = split_arguments(arguments)
    return run_command(build_claude_command(Path(probe_settings.name), probe))


def _checkout_root() -> Path | None:
  """Return the root of the checkout holding the working directory, if any."""
  toplevel = subprocess.run(
    ['git', 'rev-parse', '--show-toplevel'],
    capture_output=True,
    text=True,
    check=False,
  )
  if toplevel.returncode != 0:
    return None
  return Path(toplevel.stdout.strip())


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:], _checkout_root()))
