# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Behavior spec for reproduce_bug, exercised through its public entry point:
# main() turning a command line into the browser launch it runs. A fake machine
# stands in for the build, the files, and the launch itself.

import datetime
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest
from reproduce_bug import main


class _FakeMachine:
  """Stands in for this computer, recording the commands a run would execute."""

  chromium_app = Path('/fake/Chromium.app')

  def __init__(
    self,
    *,
    files: Mapping[str, str] | None = None,
    has_build: bool = True,
    exit_status: int = 0,
  ) -> None:
    self.commands: list[Sequence[str]] = []
    self._files = files or {}
    self._has_build = has_build
    self._exit_status = exit_status

  def has_chromium_build(self) -> bool:
    return self._has_build

  def read_text(self, path: Path) -> str:
    if str(path) not in self._files:
      raise FileNotFoundError(f'no such file: {path}')
    return self._files[str(path)]

  def make_profile_directory(self) -> Path:
    return Path('/fake/profile')

  def prepare_log_file(self, name: str) -> Path:
    return Path('/fake/logs') / name

  def now(self) -> datetime.datetime:
    return datetime.datetime(2026, 10, 19, 18, 55, 16)

  def run(self, command: Sequence[str]) -> int:
    self.commands.append(command)
    return self._exit_status


def _launched_command(
  argv: Sequence[str], files: Mapping[str, str] | None = None
) -> Sequence[str]:
  """The one command main() runs for `argv`, failing if the run fails."""
  machine = _FakeMachine(files=files)
  assert main(argv, machine) == 0
  [command] = machine.commands
  return command


def _value_of_switch(command: Sequence[str], name: str) -> str | None:
  """The value `command` gives the switch `name`, or `None` if it's absent."""
  prefix = f'{name}='
  return next(
    (
      argument.removeprefix(prefix)
      for argument in command
      if argument.startswith(prefix)
    ),
    None,
  )


# --- launching ---


def test_a_plain_run_opens_a_new_instance_with_only_the_fixed_switches() -> (
  None
):
  command = _launched_command([])

  assert command == [
    'open',
    '-n',
    '-W',
    '-a',
    '/fake/Chromium.app',
    '--args',
    '--disable-field-trial-config',
    '--no-first-run',
    '--use-mock-keychain',
    '--enable-logging',
    '--user-data-dir=/fake/profile',
    '--log-file=/fake/logs/plain-20261019-185516.log',
  ]


def test_switches_after_a_double_dash_reach_the_browser_last() -> None:
  command = _launched_command(['--', '--vmodule=*focus*=1'])

  assert command[-1] == '--vmodule=*focus*=1'


def test_a_run_reports_where_its_log_lands(
  capsys: pytest.CaptureFixture[str],
) -> None:
  _launched_command([])

  assert '/fake/logs/plain-20261019-185516.log' in capsys.readouterr().out


def test_a_missing_build_is_reported_without_launching(
  capsys: pytest.CaptureFixture[str],
) -> None:
  machine = _FakeMachine(has_build=False)

  exit_status = main([], machine)

  assert exit_status == 1
  assert machine.commands == []
  assert 'has the build finished' in capsys.readouterr().err


def test_a_failed_launch_passes_on_its_exit_status(
  capsys: pytest.CaptureFixture[str],
) -> None:
  machine = _FakeMachine(exit_status=3)

  exit_status = main([], machine)

  assert exit_status == 3
  assert 'status 3' in capsys.readouterr().err


# --- starting from saved variations ---


def test_saved_variations_reach_the_browser() -> None:
  command = _launched_command(
    ['--variations', '/saved/variations.txt'],
    files={'/saved/variations.txt': '--force-fieldtrials="Study/Group"'},
  )

  assert '--force-fieldtrials=Study/Group' in command


def test_a_switch_both_saved_and_fixed_appears_once() -> None:
  command = _launched_command(
    ['--variations', '/saved/variations.txt'],
    files={'/saved/variations.txt': '--disable-field-trial-config'},
  )

  assert command.count('--disable-field-trial-config') == 1


def test_an_override_replaces_what_the_saved_variations_say() -> None:
  command = _launched_command(
    ['--variations', '/saved/variations.txt', '--disable-feature', 'Alpha'],
    files={
      '/saved/variations.txt': (
        '--enable-features="Alpha<Study,Beta" --disable-features="Gamma"'
      )
    },
  )

  assert _value_of_switch(command, '--enable-features') == 'Beta'
  assert _value_of_switch(command, '--disable-features') == 'Gamma,Alpha'


def test_an_override_matches_a_saved_entry_marked_with_a_star() -> None:
  command = _launched_command(
    ['--variations', '/saved/variations.txt', '--enable-feature', 'Alpha'],
    files={'/saved/variations.txt': '--enable-features="*Alpha<Study,Beta"'},
  )

  assert _value_of_switch(command, '--enable-features') == 'Beta,Alpha'


def test_an_override_matches_a_saved_entry_with_parameters() -> None:
  command = _launched_command(
    ['--variations', '/saved/variations.txt', '--disable-feature', 'Alpha'],
    files={'/saved/variations.txt': '--enable-features="Alpha:size/2"'},
  )

  # The saved enabled list is left empty, so its switch is dropped.
  assert _value_of_switch(command, '--enable-features') is None
  assert _value_of_switch(command, '--disable-features') == 'Alpha'


def test_an_empty_variations_file_is_rejected_without_launching(
  capsys: pytest.CaptureFixture[str],
) -> None:
  machine = _FakeMachine(files={'/saved/variations.txt': ''})

  exit_status = main(['--variations', '/saved/variations.txt'], machine)

  assert exit_status == 1
  assert machine.commands == []
  assert 'no switches' in capsys.readouterr().err


def test_a_stray_word_in_the_variations_file_is_rejected(
  capsys: pytest.CaptureFixture[str],
) -> None:
  machine = _FakeMachine(
    files={'/saved/variations.txt': '--enable-features=Alpha stray'}
  )

  exit_status = main(['--variations', '/saved/variations.txt'], machine)

  assert exit_status == 1
  assert machine.commands == []
  assert 'stray' in capsys.readouterr().err


def test_an_unreadable_variations_file_is_reported(
  capsys: pytest.CaptureFixture[str],
) -> None:
  machine = _FakeMachine(files={})

  exit_status = main(['--variations', '/saved/variations.txt'], machine)

  assert exit_status == 1
  assert machine.commands == []
  assert 'cannot read /saved/variations.txt' in capsys.readouterr().err


# --- overrides on the command line ---


def test_overrides_alone_build_the_feature_lists() -> None:
  command = _launched_command(
    ['--enable-feature', 'Alpha', '--disable-feature', 'Beta']
  )

  assert _value_of_switch(command, '--enable-features') == 'Alpha'
  assert _value_of_switch(command, '--disable-features') == 'Beta'


@pytest.mark.parametrize(
  'argv',
  [
    pytest.param(
      ['--enable-feature', 'Alpha', '--disable-feature', 'Alpha'],
      id='conflicting',
    ),
    pytest.param(
      ['--enable-feature', 'Alpha', '--enable-feature', 'Alpha'],
      id='repeated',
    ),
  ],
)
def test_naming_a_feature_more_than_once_is_rejected(
  argv: Sequence[str], capsys: pytest.CaptureFixture[str]
) -> None:
  machine = _FakeMachine()

  with pytest.raises(SystemExit):
    main(argv, machine)

  assert machine.commands == []
  assert 'at most once' in capsys.readouterr().err


def test_a_feature_name_holding_a_comma_is_rejected(
  capsys: pytest.CaptureFixture[str],
) -> None:
  machine = _FakeMachine()

  with pytest.raises(SystemExit):
    main(['--enable-feature', 'Alpha,Beta'], machine)

  assert machine.commands == []
  assert 'bare feature name' in capsys.readouterr().err


@pytest.mark.parametrize(
  'switch', ['--enable-features=Alpha', '--user-data-dir=/tmp/profile']
)
def test_a_switch_the_script_sets_is_rejected_after_a_double_dash(
  switch: str, capsys: pytest.CaptureFixture[str]
) -> None:
  machine = _FakeMachine()

  with pytest.raises(SystemExit):
    main(['--', switch], machine)

  assert machine.commands == []
  assert 'set by this script' in capsys.readouterr().err


# --- log file names ---


def test_a_log_name_records_the_saved_variations_and_overrides() -> None:
  command = _launched_command(
    [
      '--variations',
      '/saved/variations.txt',
      '--disable-feature',
      'Alpha',
      '--enable-feature',
      'Beta',
    ],
    files={'/saved/variations.txt': '--force-fieldtrials="Study/Group"'},
  )

  assert _value_of_switch(command, '--log-file') == (
    '/fake/logs/variations-Alpha+Beta-20261019-185516.log'
  )
