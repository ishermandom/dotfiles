#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
"""Launch the local Chromium build with a fresh profile, to reproduce a bug.

A bug that one Chrome user, the reporter, sees but others can't often depends on
the reporter's experiment state, which a Chromium build never fetches on its
own. This script recreates that state from the reporter's
`chrome://version/?show-variations-cmd` export, saved to a file, and can force
single features on or off on top of it. That narrows a bug to the smallest set
of features that still shows it. Every run gets a brand-new, empty profile, so
no one's own profile is in play.

- Without `--variations`, a run starts from no experiments at all.
- `--enable-feature` and `--disable-feature` force one feature on or off,
  replacing whatever the saved variations say about it. Name each feature at
  most once.
- Switches after `--` pass straight to the browser, such as
  `--vmodule=*focus*=1` for detailed logging from matching source files. A
  switch there replaces any saved variations switch of the same name, but may
  not repeat one this script sets itself.

Every run passes `--disable-field-trial-config`, which keeps a Chromium build
from layering its own testing experiments on top. The browser's log lands in
`/Users/Shared/transfer/repro-logs/`, outside this public repo, named for the
starting settings and any overrides.
"""

import argparse
import collections
import datetime
import re
import shlex
import subprocess
import sys
import tempfile
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Protocol

CHROMIUM_APP = Path('/Users/Shared/code/chromium/src/out/Default/Chromium.app')
LOG_DIRECTORY = Path('/Users/Shared/transfer/repro-logs')

# Switches every run passes, all without values. `--no-first-run` and
# `--use-mock-keychain` keep startup dialogs from taking focus, and
# `--enable-logging` turns on the log that `--log-file` names, which a release
# build otherwise skips.
FIXED_SWITCHES = (
  '--disable-field-trial-config',
  '--no-first-run',
  '--use-mock-keychain',
  '--enable-logging',
)


class FeatureAction(Enum):
  """Whether an override forces a feature on or off."""

  ENABLE = 'enable'
  DISABLE = 'disable'

  @property
  def switch(self) -> str:
    """The browser switch that lists features in this state."""
    return f'--{self.value}-features'

  @property
  def log_mark(self) -> str:
    """The mark that records an override of this kind in a log file name."""
    return '+' if self is FeatureAction.ENABLE else '-'


FEATURE_LIST_SWITCHES = frozenset(action.switch for action in FeatureAction)

# Every switch this script sets, which a switch after `--` may not repeat.
SCRIPT_SET_SWITCHES = frozenset(
  {*FIXED_SWITCHES, *FEATURE_LIST_SWITCHES, '--user-data-dir', '--log-file'}
)


@dataclass(frozen=True)
class FeatureOverride:
  """One feature to force on or off, on top of the saved variations."""

  feature: str
  action: FeatureAction


@dataclass(frozen=True)
class RunOptions:
  """The settings for one run, as given on the command line."""

  variations_file: Path | None
  feature_overrides: tuple[FeatureOverride, ...]
  browser_switches: tuple[str, ...]


class Machine(Protocol):
  """Everything a run needs from this computer, so tests can stand in for it."""

  @property
  def chromium_app(self) -> Path:
    """The app bundle a run launches."""
    ...

  def has_chromium_build(self) -> bool:
    """Whether the build has produced the app's executable yet."""
    ...

  def read_text(self, path: Path) -> str:
    """The contents of the file at `path`; raises `OSError` on failure."""
    ...

  def make_profile_directory(self) -> Path:
    """A new, empty folder for the run's browser profile."""
    ...

  def prepare_log_file(self, name: str) -> Path:
    """The path where the run's browser log goes, under the given name."""
    ...

  def now(self) -> datetime.datetime:
    """The current local time."""
    ...

  def run(self, command: Sequence[str]) -> int:
    """Run `command` until it exits, and return its exit status."""
    ...


class LocalMachine:
  """This computer: the local build, the shared log folder, real processes."""

  @property
  def chromium_app(self) -> Path:
    return CHROMIUM_APP

  def has_chromium_build(self) -> bool:
    # The build creates the app's folders early, so check for the executable.
    return (CHROMIUM_APP / 'Contents' / 'MacOS' / 'Chromium').is_file()

  def read_text(self, path: Path) -> str:
    return path.read_text()

  def make_profile_directory(self) -> Path:
    return Path(tempfile.mkdtemp(prefix='chromium-repro.'))

  def prepare_log_file(self, name: str) -> Path:
    LOG_DIRECTORY.mkdir(parents=True, exist_ok=True)
    return LOG_DIRECTORY / name

  def now(self) -> datetime.datetime:
    return datetime.datetime.now()

  def run(self, command: Sequence[str]) -> int:
    return subprocess.run(command, check=False).returncode


def _feature_override(feature: str, action: FeatureAction) -> FeatureOverride:
  """An override of `feature`, after checking that the name is usable.

  A comma or study marker in the name would corrupt the feature lists the
  override is written into.

  Raises:
    argparse.ArgumentTypeError: the name holds anything but letters, digits,
      and underscores.
  """
  if not re.fullmatch(r'\w+', feature):
    raise argparse.ArgumentTypeError(
      f'expected a bare feature name such as WebUILocationBar, got {feature!r}'
    )
  return FeatureOverride(feature, action)


def _enable_override(feature: str) -> FeatureOverride:
  """An override forcing `feature` on, as argparse's `type=` converter."""
  return _feature_override(feature, FeatureAction.ENABLE)


def _disable_override(feature: str) -> FeatureOverride:
  """An override forcing `feature` off, as argparse's `type=` converter."""
  return _feature_override(feature, FeatureAction.DISABLE)


def _parse_arguments(argv: Sequence[str]) -> RunOptions:
  """Parse and check this script's command line.

  Rejects a feature named more than once, and a switch after `--` that repeats
  one this script sets: both say one thing two ways, which is almost certainly a
  mistake. Exits through argparse, with a usage message, on any error.
  """
  parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter,
  )
  parser.add_argument(
    '--variations',
    type=Path,
    metavar='FILE',
    help='a saved chrome://version/?show-variations-cmd export to start from',
  )
  # Both override options append to one list, which keeps every override for the
  # repeated-feature check below.
  parser.add_argument(
    '--enable-feature',
    dest='feature_overrides',
    action='append',
    type=_enable_override,
    metavar='NAME',
    help='force a feature on; repeatable for different features',
  )
  parser.add_argument(
    '--disable-feature',
    dest='feature_overrides',
    action='append',
    type=_disable_override,
    metavar='NAME',
    help='force a feature off; repeatable for different features',
  )
  parser.add_argument(
    'browser_switches',
    nargs='*',
    metavar='BROWSER_SWITCH',
    help='after `--`, switches passed straight to the browser',
  )
  namespace = parser.parse_args(argv)
  options = RunOptions(
    variations_file=namespace.variations,
    feature_overrides=tuple(namespace.feature_overrides or ()),
    browser_switches=tuple(namespace.browser_switches),
  )

  feature_counts = collections.Counter(
    override.feature for override in options.feature_overrides
  )
  repeated_features = sorted(
    feature for feature, count in feature_counts.items() if count > 1
  )
  if repeated_features:
    parser.error(
      f'name each feature at most once; repeated: '
      f'{", ".join(repeated_features)}'
    )

  for switch in options.browser_switches:
    switch_name = switch.partition('=')[0]
    if switch_name in SCRIPT_SET_SWITCHES:
      hint = (
        ' Use --enable-feature or --disable-feature instead.'
        if switch_name in FEATURE_LIST_SWITCHES
        else ''
      )
      parser.error(
        f"{switch_name} is set by this script, so it can't also follow --."
        f'{hint}'
      )
  return options


def _parse_switches(variations_text: str) -> dict[str, str]:
  """Split a variations export into its switches, keyed by name.

  The export is a shell-style command line with quoted values; `shlex` splits it
  the way a shell would, without running anything inside it. A switch with no
  value, such as `--disable-field-trial-config`, maps to an empty string.

  Raises:
    ValueError: the text has unbalanced quotes, holds no switches, or holds
      something other than a switch.
  """
  switches: dict[str, str] = {}
  for argument in shlex.split(variations_text):
    if not argument.startswith('--'):
      raise ValueError(
        f'expected only switches in the variations export, found '
        f'{argument[:80]!r}'
      )
    name, _, value = argument.partition('=')
    switches[name] = value
  if not switches:
    raise ValueError('found no switches in the variations export')
  return switches


def _feature_name(entry: str) -> str:
  """The feature that one entry of a feature list names.

  An entry reads `[*]Name[<Study[.Group]][:param/value...]`. The `*` keeps a
  feature tied to its study but at its default state.
  """
  return re.split(r'[<:]', entry, maxsplit=1)[0].removeprefix('*')


def _experiment_switches(
  variations_text: str | None,
  feature_overrides: Sequence[FeatureOverride],
) -> dict[str, str]:
  """A run's experiment switches: the saved variations, plus the overrides.

  Each override removes its feature from both saved feature lists, then adds it
  to the list its action names, so it replaces whatever the saved variations
  said about that feature.

  Raises:
    ValueError: `variations_text` isn't a usable variations export.
  """
  # An empty export is an error rather than "no experiments", so only `None`
  # means starting from nothing.
  switches = (
    _parse_switches(variations_text) if variations_text is not None else {}
  )
  overridden_features = {override.feature for override in feature_overrides}
  feature_lists = {
    action: [
      entry
      for entry in switches.pop(action.switch, '').split(',')
      if entry and _feature_name(entry) not in overridden_features
    ]
    for action in FeatureAction
  }
  for override in feature_overrides:
    feature_lists[override.action].append(override.feature)

  for action, entries in feature_lists.items():
    if entries:
      switches[action.switch] = ','.join(entries)
  return switches


def _browser_command(
  chromium_app: Path,
  experiment_switches: Mapping[str, str],
  browser_switches: Sequence[str],
  profile_directory: Path,
  log_file: Path,
) -> list[str]:
  """The `open` command that launches the build for one run.

  Launching through `open` matches launching from the Dock or Finder, which
  matters for bugs that depend on how the app becomes active. The browser takes
  the last copy of a repeated switch, so switches after `--` come last.
  """
  # Later entries win, so a switch both fixed and saved appears once.
  switches = {
    **experiment_switches,
    **dict.fromkeys(FIXED_SWITCHES, ''),
    '--user-data-dir': str(profile_directory),
    '--log-file': str(log_file),
  }
  return [
    'open',
    # Start a new instance, even when Chromium is already running.
    '-n',
    # Wait until that instance quits, so the run lasts as long as the browser.
    '-W',
    # Open the app bundle that follows.
    '-a',
    str(chromium_app),
    # Pass everything after this to the app as its command-line arguments.
    '--args',
    *(f'{name}={value}' if value else name for name, value in switches.items()),
    *browser_switches,
  ]


def _log_file_name(options: RunOptions, started_at: datetime.datetime) -> str:
  """A log file name recording a run's starting settings and overrides.

  A run from `variations.txt` with `DeferLayoutDuringBrowserStartup` forced off
  logs to `variations-DeferLayoutDuringBrowserStartup-20261019-185516.log`.
  """
  starting_point = (
    options.variations_file.stem if options.variations_file else 'plain'
  )
  overrides = ''.join(
    f'{override.action.log_mark}{override.feature}'
    for override in options.feature_overrides
  )
  return f'{starting_point}{overrides}-{started_at:%Y%m%d-%H%M%S}.log'


def main(argv: Sequence[str], machine: Machine) -> int:
  """Launch one run and wait until the browser quits; return the exit status."""
  options = _parse_arguments(argv)

  if not machine.has_chromium_build():
    print(
      f'error: no Chromium build at {machine.chromium_app}; has the build '
      f'finished?',
      file=sys.stderr,
    )
    return 1

  variations_text = None
  if options.variations_file:
    try:
      variations_text = machine.read_text(options.variations_file)
    except OSError as error:
      print(
        f'error: cannot read {options.variations_file}: {error}',
        file=sys.stderr,
      )
      return 1
  try:
    switches = _experiment_switches(variations_text, options.feature_overrides)
  except ValueError as error:
    print(f'error: in {options.variations_file}: {error}', file=sys.stderr)
    return 1

  profile_directory = machine.make_profile_directory()
  log_file = machine.prepare_log_file(_log_file_name(options, machine.now()))
  command = _browser_command(
    machine.chromium_app,
    switches,
    options.browser_switches,
    profile_directory,
    log_file,
  )

  print(f'Launching Chromium with an empty profile at {profile_directory}')
  print('Reproduce the bug, then quit Chromium with Cmd+Q.')
  exit_status = machine.run(command)
  if exit_status != 0:
    print(f'error: open exited with status {exit_status}', file=sys.stderr)
    return exit_status

  print(f"Done. The browser's log is at {log_file}")
  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:], LocalMachine()))
