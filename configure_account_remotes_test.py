# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

"""Tests for the shared-repo remote configuration."""

import subprocess
from pathlib import Path

import pytest

from configure_account_remotes import (
  ACCOUNT_REMOTE_INCLUDE,
  RemotePlan,
  SkipReason,
  describe_skip,
  github_path_of,
  main,
  plan_remotes,
  repository_checkouts,
)


def _make_repository(path: Path) -> None:
  """Create a git repository at `path` with one commit to branch from."""
  subprocess.run(['git', 'init', '-q', '-b', 'main', str(path)], check=True)
  _run_git(path, 'commit', '-q', '--allow-empty', '-m', 'seed')


def _run_git(repo: Path, *arguments: str) -> None:
  """Run a git command in `repo`, failing the test if it errors."""
  subprocess.run(['git', '-C', str(repo), *arguments], check=True)


def _remote_url(repo: Path, remote: str) -> str:
  """The URL `remote` currently holds, empty when it has none."""
  result = subprocess.run(
    ['git', '-C', str(repo), 'remote', 'get-url', remote],
    capture_output=True,
    text=True,
    check=False,
  )
  return result.stdout.strip()


def _include_paths(repo: Path) -> list[str]:
  """Every include.path entry in the repository's own config."""
  result = subprocess.run(
    ['git', '-C', str(repo), 'config', '--local', '--get-all', 'include.path'],
    capture_output=True,
    text=True,
    check=False,
  )
  return result.stdout.split()


def _make_shared_tree(tmp_path: Path) -> tuple[Path, Path]:
  """A shared code directory alongside a present account-remote file."""
  shared = tmp_path / 'code'
  shared.mkdir()
  account_remote_file = tmp_path / 'account-remote'
  account_remote_file.write_text('[branch "main"]\n\tremote = origin-https\n')
  return shared, account_remote_file


# --- github_path_of ---


def test_ssh_url_yields_owner_and_repo() -> None:
  assert github_path_of('git@github.com:ishermandom/bridge.git') == (
    'ishermandom/bridge'
  )


def test_https_url_yields_owner_and_repo() -> None:
  assert github_path_of('https://github.com/ishermandom/bridge.git') == (
    'ishermandom/bridge'
  )


def test_https_url_without_git_suffix_yields_owner_and_repo() -> None:
  assert github_path_of('https://github.com/ishermandom/dotfiles') == (
    'ishermandom/dotfiles'
  )


@pytest.mark.parametrize(
  'url',
  [
    '',
    'https://gitlab.com/someone/thing.git',
    'git@gitlab.com:someone/thing.git',
    'https://github.com/ishermandom',
    'https://github.com/ishermandom/',
    'https://github.com/ishermandom/nested/repo',
    '/Users/Shared/code/local-only',
  ],
)
def test_urls_that_are_not_github_repositories_are_rejected(url: str) -> None:
  assert github_path_of(url) is None


# --- plan_remotes ---


def test_a_correct_pair_needs_no_changes() -> None:
  plan = plan_remotes(
    'git@github.com:ishermandom/bridge.git',
    'https://github.com/ishermandom/bridge.git',
  )

  assert plan == RemotePlan()


def test_an_https_origin_is_repointed_to_ssh() -> None:
  plan = plan_remotes('https://github.com/ishermandom/bridge.git', '')

  assert plan.ssh_url == 'git@github.com:ishermandom/bridge.git'


def test_a_missing_https_remote_is_added() -> None:
  plan = plan_remotes('git@github.com:ishermandom/bridge.git', '')

  assert plan.https_url == 'https://github.com/ishermandom/bridge.git'
  assert not plan.ssh_url


def test_a_working_https_url_keeps_its_exact_form() -> None:
  # credential.useHttpPath keys stored credentials on the full path, so a URL
  # that already reaches the right repo is left alone even without the .git
  # suffix that a freshly built one would carry.
  plan = plan_remotes(
    'git@github.com:ishermandom/dotfiles.git',
    'https://github.com/ishermandom/dotfiles',
  )

  assert not plan.https_url


def test_origin_is_derived_from_the_https_remote() -> None:
  plan = plan_remotes('', 'https://github.com/ishermandom/bridge.git')

  assert plan.ssh_url == 'git@github.com:ishermandom/bridge.git'


def test_another_accounts_repository_is_skipped() -> None:
  plan = plan_remotes('https://github.com/someone-else/thing.git', '')

  assert plan.skip_reason is SkipReason.FOREIGN_OWNER
  assert plan.foreign_owner == 'someone-else'


def test_a_non_github_remote_is_skipped() -> None:
  plan = plan_remotes('https://gitlab.com/someone/thing.git', '')

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE


def test_a_repository_with_no_remotes_is_skipped() -> None:
  plan = plan_remotes('', '')

  assert plan.skip_reason is SkipReason.NO_GITHUB_REMOTE


def test_a_non_github_origin_is_never_overwritten() -> None:
  # The counterpart URL is derivable here, which is exactly the trap: rewriting
  # origin would discard a remote pointing somewhere else entirely.
  plan = plan_remotes(
    'https://gitlab.com/team/thing.git',
    'https://github.com/ishermandom/bridge.git',
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE
  assert not plan.ssh_url


def test_a_non_github_https_remote_is_never_overwritten() -> None:
  plan = plan_remotes(
    'git@github.com:ishermandom/bridge.git',
    'https://gitlab.com/team/thing.git',
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE
  assert not plan.https_url


def test_a_local_path_origin_is_never_overwritten() -> None:
  plan = plan_remotes(
    '/Users/Shared/code/local-mirror',
    'https://github.com/ishermandom/bridge.git',
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE


def test_remotes_naming_different_repositories_are_skipped() -> None:
  plan = plan_remotes(
    'git@github.com:ishermandom/alpha.git',
    'https://github.com/ishermandom/beta.git',
  )

  assert plan.skip_reason is SkipReason.CONFLICTING_REMOTES
  assert not plan.ssh_url
  assert not plan.https_url


# --- describe_skip ---


def test_a_foreign_owner_is_named_in_the_reason() -> None:
  assert 'someone-else' in describe_skip(
    SkipReason.FOREIGN_OWNER, 'someone-else'
  )


def test_other_reasons_use_their_own_wording() -> None:
  assert 'GitHub' in describe_skip(SkipReason.NO_GITHUB_REMOTE, None)


# --- repository_checkouts ---


def test_a_plain_checkout_is_returned(tmp_path: Path) -> None:
  _make_repository(tmp_path / 'solo')

  assert repository_checkouts(tmp_path) == [tmp_path / 'solo']


def test_a_directory_that_is_not_a_checkout_is_ignored(tmp_path: Path) -> None:
  (tmp_path / 'not-a-repo').mkdir()

  assert repository_checkouts(tmp_path) == []


def test_a_missing_shared_directory_yields_nothing(tmp_path: Path) -> None:
  assert repository_checkouts(tmp_path / 'absent') == []


def test_worktrees_collapse_onto_the_checkout_owning_the_config(
  tmp_path: Path,
) -> None:
  main_checkout = tmp_path / 'main-repo'
  _make_repository(main_checkout)
  worktree = tmp_path / 'a-worktree'
  _run_git(main_checkout, 'worktree', 'add', '-q', str(worktree), '-b', 'side')

  # Two checkouts, one config, so one entry — named for the owning checkout.
  assert repository_checkouts(tmp_path) == [main_checkout]


def test_a_worktree_owned_from_a_nested_repo_is_left_out(
  tmp_path: Path,
) -> None:
  # Nested under the shared tree, but not a repo a plain scan would find, so
  # following the worktree must not pull it into scope either.
  nested_parent = tmp_path / 'group'
  nested_parent.mkdir()
  main_checkout = nested_parent / 'main-repo'
  _make_repository(main_checkout)
  worktree = tmp_path / 'a-worktree'
  _run_git(main_checkout, 'worktree', 'add', '-q', str(worktree), '-b', 'side')

  assert repository_checkouts(tmp_path) == []


def test_a_worktree_owned_from_outside_is_left_out(tmp_path: Path) -> None:
  # Configuring it would write to a repository never placed in the shared tree.
  outside = tmp_path / 'outside'
  outside.mkdir()
  shared = tmp_path / 'shared'
  shared.mkdir()
  main_checkout = outside / 'main-repo'
  _make_repository(main_checkout)
  worktree = shared / 'a-worktree'
  _run_git(main_checkout, 'worktree', 'add', '-q', str(worktree), '-b', 'side')

  assert repository_checkouts(shared) == []


# --- main ---


def test_a_repository_is_brought_fully_into_line(tmp_path: Path) -> None:
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/ishermandom/bridge.git'
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  assert exit_code == 0
  assert _remote_url(repo, 'origin') == 'git@github.com:ishermandom/bridge.git'
  assert _remote_url(repo, 'origin-https') == (
    'https://github.com/ishermandom/bridge.git'
  )
  assert _include_paths(repo) == [ACCOUNT_REMOTE_INCLUDE]


def test_a_second_run_changes_nothing(tmp_path: Path) -> None:
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/ishermandom/bridge.git'
  )
  main([], shared_code_dir=shared, account_remote_file=account_remote_file)

  main([], shared_code_dir=shared, account_remote_file=account_remote_file)

  # One include, not two: re-running must not stack duplicates.
  assert _include_paths(repo) == [ACCOUNT_REMOTE_INCLUDE]


def test_a_dry_run_writes_nothing(tmp_path: Path) -> None:
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/ishermandom/bridge.git'
  )

  exit_code = main(
    ['-n'], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  assert exit_code == 0
  assert (
    _remote_url(repo, 'origin') == 'https://github.com/ishermandom/bridge.git'
  )
  assert _remote_url(repo, 'origin-https') == ''
  assert _include_paths(repo) == []


def test_another_accounts_repository_is_left_untouched(tmp_path: Path) -> None:
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'theirs'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/someone-else/thing.git'
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  assert exit_code == 0
  assert (
    _remote_url(repo, 'origin') == 'https://github.com/someone-else/thing.git'
  )
  assert _remote_url(repo, 'origin-https') == ''
  assert _include_paths(repo) == []


def test_a_non_github_origin_survives_a_full_run(tmp_path: Path) -> None:
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'mirrored'
  _make_repository(repo)
  _run_git(repo, 'remote', 'add', 'origin', 'https://gitlab.com/team/thing.git')
  _run_git(
    repo,
    'remote',
    'add',
    'origin-https',
    'https://github.com/ishermandom/bridge.git',
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  assert exit_code == 0
  assert _remote_url(repo, 'origin') == 'https://gitlab.com/team/thing.git'
  assert _include_paths(repo) == []


def test_a_missing_account_remote_file_stops_the_run(tmp_path: Path) -> None:
  shared, _ = _make_shared_tree(tmp_path)

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=tmp_path / 'absent'
  )

  assert exit_code == 1


def test_a_dry_run_previews_without_the_account_remote_file(
  tmp_path: Path,
) -> None:
  # stow's own dry run never creates the file, so install.sh -n must still work.
  shared, _ = _make_shared_tree(tmp_path)

  exit_code = main(
    ['-n'], shared_code_dir=shared, account_remote_file=tmp_path / 'absent'
  )

  assert exit_code == 0
