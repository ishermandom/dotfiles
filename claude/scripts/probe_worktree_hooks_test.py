# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
"""Tests for probe_worktree_hooks."""

import io
import json
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest
from probe_worktree_hooks import (
  MalformedSettingsError,
  build_claude_command,
  hook_entries,
  main,
  names_permission_mode,
  redirect_hook_commands,
  split_arguments,
)


def _make_settings(
  command: str = '~/.claude/hooks/example.py',
) -> dict[str, object]:
  """Build a settings object wiring `command` as a PostToolUse hook."""
  return {
    'hooks': {
      'PostToolUse': [
        {
          'matcher': 'Edit|Write',
          'hooks': [{'type': 'command', 'command': command}],
        }
      ]
    }
  }


def _commands(settings: Mapping[str, object]) -> list[str]:
  """Collect every hook command in `settings`, for assertions."""
  return [str(entry['command']) for entry in hook_entries(settings)]


def _write_checkout(root: Path, settings_text: str) -> Path:
  """Create a checkout at `root` whose settings.json holds `settings_text`."""
  (root / 'claude').mkdir(parents=True)
  (root / 'claude' / 'settings.json').write_text(settings_text)
  return root


# --- redirecting hook commands ----------------------------------------------


def test_hook_command_moves_into_the_checkout() -> None:
  settings = _make_settings('~/.claude/hooks/example.py')

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert _commands(settings) == ['/worktree/claude/hooks/example.py']


def test_script_behind_an_interpreter_moves_too() -> None:
  # A path left at its installed spelling would run the installed copy and
  # report a passing probe for a hook this checkout never fired.
  settings = _make_settings('python3 ~/.claude/hooks/example.py --strict')

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert _commands(settings) == [
    'python3 /worktree/claude/hooks/example.py --strict'
  ]


def test_every_script_in_a_chained_command_moves() -> None:
  settings = _make_settings('~/.claude/hooks/one.py && ~/.claude/hooks/two.py')

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert _commands(settings) == [
    '/worktree/claude/hooks/one.py && /worktree/claude/hooks/two.py'
  ]


def test_command_outside_the_installed_config_is_left_alone() -> None:
  settings = _make_settings('/usr/local/bin/formatter')

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert _commands(settings) == ['/usr/local/bin/formatter']


def test_permission_rules_are_left_alone() -> None:
  # A permission rule matches the literal text of the command it allows, so
  # rewriting it would stop it matching the `~/.claude` spelling sessions use.
  settings = _make_settings()
  settings['permissions'] = {
    'allow': ['Bash(~/.claude/scripts/quiet-tests.sh:*)']
  }

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert settings['permissions'] == {
    'allow': ['Bash(~/.claude/scripts/quiet-tests.sh:*)']
  }


def test_settings_without_hooks_are_accepted() -> None:
  settings: dict[str, object] = {'model': 'opus'}

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert settings == {'model': 'opus'}


def test_every_event_and_matcher_group_is_reached() -> None:
  settings = {
    'hooks': {
      'PostToolUse': [
        {'matcher': 'Edit', 'hooks': [{'command': '~/.claude/hooks/one.py'}]},
        {'matcher': 'Bash', 'hooks': [{'command': '~/.claude/hooks/two.py'}]},
      ],
      'Stop': [
        {'matcher': '', 'hooks': [{'command': '~/.claude/hooks/three.sh'}]}
      ],
    }
  }

  redirect_hook_commands(settings, Path('/worktree/claude'))

  assert _commands(settings) == [
    '/worktree/claude/hooks/one.py',
    '/worktree/claude/hooks/two.py',
    '/worktree/claude/hooks/three.sh',
  ]


# --- rejecting a settings shape that would hide a hook -----------------------


@pytest.mark.parametrize(
  'settings',
  [
    {'hooks': 'PostToolUse'},
    {'hooks': {'PostToolUse': {'matcher': 'Edit'}}},
    {'hooks': {'PostToolUse': ['not a matcher group']}},
    {'hooks': {'PostToolUse': [{'hooks': 'not a list'}]}},
    {'hooks': {'PostToolUse': [{'hooks': ['not a hook']}]}},
  ],
)
def test_unexpected_shape_is_rejected(settings: Mapping[str, object]) -> None:
  # Skipping a malformed level would leave its hook's installed path in place,
  # pointing the probe back at the installed copy.
  with pytest.raises(MalformedSettingsError):
    redirect_hook_commands(settings, Path('/worktree/claude'))


def test_rejection_names_the_event_that_broke() -> None:
  settings = {'hooks': {'SessionEnd': 'not a list of matcher groups'}}

  with pytest.raises(MalformedSettingsError, match='SessionEnd'):
    redirect_hook_commands(settings, Path('/worktree/claude'))


def test_rejection_names_which_matcher_group_broke() -> None:
  # An event can register several groups, so the event name alone would not say
  # which one to go and look at.
  settings = {
    'hooks': {
      'PostToolUse': [
        {'matcher': 'Edit', 'hooks': [{'command': '~/.claude/hooks/one.py'}]},
        {'matcher': 'Bash', 'hooks': 'not a list'},
      ]
    }
  }

  with pytest.raises(MalformedSettingsError, match='matcher group 1'):
    redirect_hook_commands(settings, Path('/worktree/claude'))


# --- splitting options from the prompt ---------------------------------------


def test_a_lone_argument_is_the_prompt() -> None:
  probe = split_arguments(['Say ok'])

  assert probe.options == ()
  assert probe.prompt == 'Say ok'


def test_options_precede_the_prompt() -> None:
  probe = split_arguments(['--permission-mode', 'plan', 'Say ok'])

  assert probe.options == ('--permission-mode', 'plan')
  assert probe.prompt == 'Say ok'


# --- choosing a permission mode ----------------------------------------------


def test_separate_permission_mode_value_is_recognized() -> None:
  assert names_permission_mode(['--permission-mode', 'plan'])


def test_joined_permission_mode_value_is_recognized() -> None:
  assert names_permission_mode(['--permission-mode=plan'])


def test_no_permission_mode_among_other_options() -> None:
  assert not names_permission_mode(['--verbose', '--model', 'opus'])


# --- assembling the claude command -------------------------------------------


def test_command_loads_the_rewritten_settings_without_user_sources() -> None:
  probe = split_arguments(['Say ok'])

  command = build_claude_command(Path('/tmp/probe.json'), probe)

  assert '--settings' in command
  assert command[command.index('--settings') + 1] == '/tmp/probe.json'
  assert command[command.index('--setting-sources') + 1] == 'project'


def test_permission_mode_defaults_so_an_edit_runs_unattended() -> None:
  probe = split_arguments(['Use the Write tool to create probe.md'])

  command = build_claude_command(Path('/tmp/probe.json'), probe)

  assert command[command.index('--permission-mode') + 1] == 'acceptEdits'


def test_callers_permission_mode_stands() -> None:
  probe = split_arguments(['--permission-mode', 'bypassPermissions', 'Say ok'])

  command = build_claude_command(Path('/tmp/probe.json'), probe)

  assert 'acceptEdits' not in command
  assert command[command.index('--permission-mode') + 1] == 'bypassPermissions'


def test_prompt_mentioning_a_permission_mode_still_gets_the_default() -> None:
  # The prompt is an argument like any other, so a probe of permission handling
  # would otherwise read its own subject matter as an option.
  probe = split_arguments(['Explain what --permission-mode plan does'])

  command = build_claude_command(Path('/tmp/probe.json'), probe)

  assert command[command.index('--permission-mode') + 1] == 'acceptEdits'


def test_prompt_is_the_final_argument() -> None:
  probe = split_arguments(['--verbose', 'Say ok'])

  command = build_claude_command(Path('/tmp/probe.json'), probe)

  assert command[-1] == 'Say ok'
  assert '--verbose' in command


# --- running a probe ---------------------------------------------------------


class _RecordingRunner:
  """Stands in for the `claude` invocation, recording what it was handed."""

  def __init__(self, exit_code: int = 0) -> None:
    self.exit_code = exit_code
    self.command: Sequence[str] = []
    self.settings_seen: object = None

  def __call__(self, command: Sequence[str]) -> int:
    self.command = command
    # The settings file exists only while the session runs, so read it now.
    settings_path = Path(command[command.index('--settings') + 1])
    self.settings_seen = json.loads(settings_path.read_text())
    return self.exit_code


def test_probe_hands_the_session_the_rewritten_settings(tmp_path: Path) -> None:
  checkout = _write_checkout(tmp_path, json.dumps(_make_settings()))
  runner = _RecordingRunner()

  exit_code = main(['Say ok'], checkout, run_command=runner)

  assert exit_code == 0
  assert runner.settings_seen == _make_settings(
    str(checkout / 'claude' / 'hooks' / 'example.py')
  )


def test_rewritten_settings_are_removed_after_the_session(
  tmp_path: Path,
) -> None:
  checkout = _write_checkout(tmp_path, json.dumps(_make_settings()))
  runner = _RecordingRunner()

  main(['Say ok'], checkout, run_command=runner)

  settings_path = Path(runner.command[runner.command.index('--settings') + 1])
  assert not settings_path.exists()


def test_probe_reports_the_sessions_exit_code(tmp_path: Path) -> None:
  checkout = _write_checkout(tmp_path, json.dumps(_make_settings()))

  exit_code = main(
    ['Say ok'], checkout, run_command=_RecordingRunner(exit_code=3)
  )

  assert exit_code == 3


# --- refusing to probe -------------------------------------------------------


def test_no_prompt_prints_usage(tmp_path: Path) -> None:
  stderr = io.StringIO()

  exit_code = main([], tmp_path, run_command=_unreachable_runner, stderr=stderr)

  assert exit_code == 2
  assert 'usage:' in stderr.getvalue()


def test_a_trailing_option_prints_usage(tmp_path: Path) -> None:
  # Taking the trailing option for the prompt would start a session with no
  # prompt, which fails inside claude rather than at this script's usage line.
  stderr = io.StringIO()

  exit_code = main(
    ['--verbose'],
    tmp_path,
    run_command=_unreachable_runner,
    stderr=stderr,
  )

  assert exit_code == 2
  assert 'usage:' in stderr.getvalue()


def test_outside_a_checkout_is_refused() -> None:
  stderr = io.StringIO()

  exit_code = main(
    ['Say ok'], None, run_command=_unreachable_runner, stderr=stderr
  )

  assert exit_code == 1
  assert 'checkout' in stderr.getvalue()


def test_checkout_without_settings_is_refused(tmp_path: Path) -> None:
  stderr = io.StringIO()

  exit_code = main(
    ['Say ok'], tmp_path, run_command=_unreachable_runner, stderr=stderr
  )

  assert exit_code == 1
  assert 'settings.json' in stderr.getvalue()


def test_settings_that_do_not_parse_are_refused(tmp_path: Path) -> None:
  # Starting a session on unparseable settings would load no hooks at all, which
  # reads as the hook under test failing to fire.
  checkout = _write_checkout(tmp_path, '{ "hooks": ')
  stderr = io.StringIO()

  exit_code = main(
    ['Say ok'], checkout, run_command=_unreachable_runner, stderr=stderr
  )

  assert exit_code == 1
  assert 'cannot read' in stderr.getvalue()


def test_settings_holding_a_list_are_refused(tmp_path: Path) -> None:
  checkout = _write_checkout(tmp_path, '["not", "an", "object"]')
  stderr = io.StringIO()

  exit_code = main(
    ['Say ok'], checkout, run_command=_unreachable_runner, stderr=stderr
  )

  assert exit_code == 1
  assert 'object' in stderr.getvalue()


def test_malformed_hooks_section_is_refused(tmp_path: Path) -> None:
  checkout = _write_checkout(tmp_path, json.dumps({'hooks': 'PostToolUse'}))
  stderr = io.StringIO()

  exit_code = main(
    ['Say ok'], checkout, run_command=_unreachable_runner, stderr=stderr
  )

  assert exit_code == 1
  assert 'malformed' in stderr.getvalue()


def _unreachable_runner(command: Sequence[str]) -> int:
  """Fail the test if a refused probe starts a session anyway."""
  raise AssertionError(
    f'started a session despite refusing to probe: {command}'
  )
