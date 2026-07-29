# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

"""Tests for the shared-repo remote configuration."""

import pytest

from configure_account_remotes import (
  RemotePlan,
  SkipReason,
  describe_skip,
  github_path_of,
  plan_remotes,
)

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

  assert plan.skip_reason is SkipReason.NO_GITHUB_REMOTE


def test_a_repository_with_no_remotes_is_skipped() -> None:
  plan = plan_remotes('', '')

  assert plan.skip_reason is SkipReason.NO_GITHUB_REMOTE


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
