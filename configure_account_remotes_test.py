# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

"""Tests for the shared-repo remote configuration.

These build real repositories under `tmp_path` rather than working in memory, as
`rules/testing.md` otherwise prefers. What is under test is what `git` does to a
repository on disk, so there is no stream to inject in place of the filesystem:
faking the subprocess would only check which arguments were assembled, and
assembling them is not where the risk is.

Every git call — the helpers' here and the code's under test — runs against the
temporary home the `isolated_git_environment` fixture sets up, so no test reads
the config of whichever account is running it.
"""

import os
import subprocess
import textwrap
from pathlib import Path

import pytest

from configure_account_remotes import (
  ACCOUNT_REMOTE_INCLUDE,
  GitHubRepository,
  Remote,
  RemotePlan,
  SkipReason,
  UnreadableRepository,
  declared_remotes_of,
  describe_skip,
  github_repository_of,
  is_already_wired,
  main,
  plan_remotes,
  remote_urls_of,
  scan_repositories,
)


@pytest.fixture(autouse=True)
def isolated_git_environment(
  tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
  """Runs every git call against a temporary home, with its own identity.

  The code under test shells out to git from this process, so the isolation has
  to live in the environment rather than in an argument. Without it the suite
  borrows whatever the running account's global config says — and on an account
  that configures no commit identity, the repository-building helpers error
  instead of the tests reporting a result.

  Pointing `HOME` at `tmp_path` is also what lets a test check where the include
  actually leads, since git expands the `~` in it per account.
  """
  monkeypatch.setenv('HOME', str(tmp_path))
  monkeypatch.setenv('GIT_CONFIG_GLOBAL', os.devnull)
  monkeypatch.setenv('GIT_CONFIG_SYSTEM', os.devnull)
  monkeypatch.setenv('GIT_AUTHOR_NAME', 'Test Author')
  monkeypatch.setenv('GIT_AUTHOR_EMAIL', 'author@example.com')
  monkeypatch.setenv('GIT_COMMITTER_NAME', 'Test Committer')
  monkeypatch.setenv('GIT_COMMITTER_EMAIL', 'committer@example.com')


def _make_repository(path: Path) -> None:
  """Create a git repository at `path` with one commit to branch from."""
  subprocess.run(['git', 'init', '-q', '-b', 'main', str(path)], check=True)
  _run_git(path, 'commit', '-q', '--allow-empty', '-m', 'seed')


def _run_git(repo: Path, *arguments: str) -> None:
  """Run a git command in `repo`, failing the test if it errors."""
  subprocess.run(['git', '-C', str(repo), *arguments], check=True)


def _corrupt_config(repo: Path) -> None:
  """Leave a section unclosed, so git refuses to read the config at all."""
  config = repo / '.git' / 'config'
  config.write_text(f'{config.read_text()}[remote "origin"\n\turl = x\n')


def _remote_url(repo: Path, remote: str) -> str:
  """The URL `remote` currently holds, empty when it has none."""
  result = subprocess.run(
    ['git', '-C', str(repo), 'config', '--get', f'remote.{remote}.url'],
    capture_output=True,
    text=True,
    check=False,
  )
  return result.stdout.strip()


def _remote_urls(repo: Path, remote: str) -> list[str]:
  """Every URL `remote` holds, so an extra one cannot go unnoticed."""
  result = subprocess.run(
    ['git', '-C', str(repo), 'config', '--get-all', f'remote.{remote}.url'],
    capture_output=True,
    text=True,
    check=False,
  )
  return result.stdout.splitlines()


def _include_paths(repo: Path) -> list[str]:
  """Every include.path entry in the repository's own config."""
  result = subprocess.run(
    ['git', '-C', str(repo), 'config', '--local', '--get-all', 'include.path'],
    capture_output=True,
    text=True,
    check=False,
  )
  return result.stdout.splitlines()


def _branch_remote(repo: Path, branch: str) -> str:
  """Which remote git resolves `branch` to, following any include."""
  result = subprocess.run(
    ['git', '-C', str(repo), 'config', '--get', f'branch.{branch}.remote'],
    capture_output=True,
    text=True,
    check=False,
  )
  return result.stdout.strip()


def _make_shared_tree(tmp_path: Path) -> tuple[Path, Path]:
  """A shared code directory alongside a present account-remote file.

  The file goes where `ACCOUNT_REMOTE_INCLUDE` resolves under the fixture's
  `HOME`, so it is the very file git reads when it follows the include.
  """
  shared = tmp_path / 'code'
  shared.mkdir()
  account_remote_file = Path(ACCOUNT_REMOTE_INCLUDE).expanduser()
  account_remote_file.parent.mkdir(parents=True, exist_ok=True)
  account_remote_file.write_text(
    textwrap.dedent("""\
      [branch "main"]
      \tremote = origin-https
    """)
  )
  return shared, account_remote_file


# --- github_repository_of ---


def test_ssh_url_yields_owner_and_repository() -> None:
  assert github_repository_of('git@github.com:ishermandom/bridge.git') == (
    GitHubRepository(owner='ishermandom', name='bridge')
  )


def test_https_url_yields_owner_and_repository() -> None:
  assert github_repository_of('https://github.com/ishermandom/bridge.git') == (
    GitHubRepository(owner='ishermandom', name='bridge')
  )


def test_https_url_without_git_suffix_yields_owner_and_repository() -> None:
  assert github_repository_of('https://github.com/ishermandom/dotfiles') == (
    GitHubRepository(owner='ishermandom', name='dotfiles')
  )


def test_ssh_scheme_url_yields_owner_and_repository() -> None:
  assert github_repository_of(
    'ssh://git@github.com/ishermandom/bridge.git'
  ) == GitHubRepository(owner='ishermandom', name='bridge')


def test_url_carrying_credentials_yields_owner_and_repository() -> None:
  # Only the host decides, so credentials in the URL do not make the repository
  # unrecognizable — which would leave the whole checkout unconfigured.
  assert github_repository_of(
    'https://ishermandom:token@github.com/ishermandom/bridge.git'
  ) == GitHubRepository(owner='ishermandom', name='bridge')


def test_trailing_slash_yields_owner_and_repository() -> None:
  assert github_repository_of('https://github.com/ishermandom/bridge/') == (
    GitHubRepository(owner='ishermandom', name='bridge')
  )


@pytest.mark.parametrize(
  'url',
  [
    'git@GitHub.com:ishermandom/bridge.git',
    'https://GitHub.COM/ishermandom/bridge.git',
  ],
)
def test_the_host_is_recognized_whatever_its_case(url: str) -> None:
  # Host names are case-insensitive, so both spellings name the repository this
  # manages — and one form recognizing a case the other rejects would leave a
  # checkout alone for no reason a reader could predict.
  assert github_repository_of(url) == GitHubRepository(
    owner='ishermandom', name='bridge'
  )


@pytest.mark.parametrize(
  'url',
  [
    '',
    'https://gitlab.com/someone/thing.git',
    'git@gitlab.com:someone/thing.git',
    'https://github.com.example.com/ishermandom/bridge.git',
    'https://github.com/ishermandom',
    'https://github.com/ishermandom/',
    'https://github.com/ishermandom/nested/repo',
    '/Users/Shared/code/local-only',
  ],
)
def test_urls_that_are_not_github_repositories_are_rejected(url: str) -> None:
  assert github_repository_of(url) is None


# --- plan_remotes ---


def test_a_correct_pair_needs_no_changes() -> None:
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/bridge.git'],
    https_urls=['https://github.com/ishermandom/bridge.git'],
  )

  assert plan == RemotePlan()


def test_an_https_origin_is_repointed_to_ssh() -> None:
  plan = plan_remotes(
    origin_urls=['https://github.com/ishermandom/bridge.git'], https_urls=[]
  )

  assert plan.ssh_url == 'git@github.com:ishermandom/bridge.git'


def test_a_missing_https_remote_is_added() -> None:
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/bridge.git'], https_urls=[]
  )

  assert plan.https_url == 'https://github.com/ishermandom/bridge.git'
  assert not plan.ssh_url


def test_a_working_https_url_keeps_its_exact_form() -> None:
  # credential.useHttpPath keys stored credentials on the full path, so a URL
  # that already reaches the right repo is left alone even without the .git
  # suffix that a freshly built one would carry.
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/dotfiles.git'],
    https_urls=['https://github.com/ishermandom/dotfiles'],
  )

  assert not plan.https_url


def test_an_https_url_carrying_credentials_keeps_its_exact_form() -> None:
  # Rewriting it to the canonical form would discard the credentials it carries.
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/bridge.git'],
    https_urls=['https://ishermandom:token@github.com/ishermandom/bridge.git'],
  )

  assert not plan.https_url


def test_origin_is_derived_from_the_https_remote() -> None:
  plan = plan_remotes(
    origin_urls=[], https_urls=['https://github.com/ishermandom/bridge.git']
  )

  assert plan.ssh_url == 'git@github.com:ishermandom/bridge.git'


def test_another_accounts_repository_is_skipped() -> None:
  plan = plan_remotes(
    origin_urls=['https://github.com/someone-else/thing.git'], https_urls=[]
  )

  assert plan.skip_reason is SkipReason.FOREIGN_OWNER
  assert plan.foreign_owner == 'someone-else'


def test_a_non_github_remote_is_skipped() -> None:
  plan = plan_remotes(
    origin_urls=['https://gitlab.com/someone/thing.git'], https_urls=[]
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE


def test_a_repository_with_no_remotes_is_skipped() -> None:
  plan = plan_remotes(origin_urls=[], https_urls=[])

  assert plan.skip_reason is SkipReason.MISSING_BOTH_REMOTES


def test_a_non_github_origin_is_never_overwritten() -> None:
  # The counterpart URL is derivable here, which is exactly the trap: rewriting
  # origin would discard a remote pointing somewhere else entirely.
  plan = plan_remotes(
    origin_urls=['https://gitlab.com/team/thing.git'],
    https_urls=['https://github.com/ishermandom/bridge.git'],
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE
  assert not plan.ssh_url


def test_a_non_github_https_remote_is_never_overwritten() -> None:
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/bridge.git'],
    https_urls=['https://gitlab.com/team/thing.git'],
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE
  assert not plan.https_url


def test_a_local_path_origin_is_never_overwritten() -> None:
  plan = plan_remotes(
    origin_urls=['/Users/Shared/code/local-mirror'],
    https_urls=['https://github.com/ishermandom/bridge.git'],
  )

  assert plan.skip_reason is SkipReason.UNRECOGNIZED_REMOTE


def test_an_origin_with_several_urls_is_skipped() -> None:
  # The extra URL would survive a rewrite of the first, so the repository is
  # left alone rather than half-corrected.
  plan = plan_remotes(
    origin_urls=[
      'git@github.com:ishermandom/beta.git',
      'https://gitlab.com/team/thing.git',
    ],
    https_urls=[],
  )

  assert plan.skip_reason is SkipReason.MULTIPLE_REMOTE_URLS
  assert not plan.ssh_url
  assert not plan.https_url


def test_an_https_remote_with_several_urls_is_skipped() -> None:
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/bridge.git'],
    https_urls=[
      'https://github.com/ishermandom/bridge.git',
      'https://gitlab.com/team/thing.git',
    ],
  )

  assert plan.skip_reason is SkipReason.MULTIPLE_REMOTE_URLS


def test_remotes_naming_different_repositories_are_skipped() -> None:
  plan = plan_remotes(
    origin_urls=['git@github.com:ishermandom/alpha.git'],
    https_urls=['https://github.com/ishermandom/beta.git'],
  )

  assert plan.skip_reason is SkipReason.CONFLICTING_REMOTES
  assert not plan.ssh_url
  assert not plan.https_url


def test_conflicting_remotes_are_reported_before_the_owner() -> None:
  # The owner is unanswerable while the two remotes disagree about which
  # repository this is, so the conflict is the reason worth reporting.
  plan = plan_remotes(
    origin_urls=['git@github.com:someone-else/thing.git'],
    https_urls=['https://github.com/ishermandom/bridge.git'],
  )

  assert plan.skip_reason is SkipReason.CONFLICTING_REMOTES


# --- describe_skip ---


def test_a_foreign_owner_is_named_in_the_reason() -> None:
  assert 'someone-else' in describe_skip(
    SkipReason.FOREIGN_OWNER, 'someone-else'
  )


def test_other_reasons_use_their_own_wording() -> None:
  assert 'origin-https' in describe_skip(SkipReason.MISSING_BOTH_REMOTES, None)


# --- reading a repository's config ---


def test_a_remote_declared_without_a_url_reports_no_url(tmp_path: Path) -> None:
  # `git remote get-url` answers for this remote by echoing its own name, which
  # would read as a URL pointing somewhere unmanaged.
  repo = tmp_path / 'urlless'
  _make_repository(repo)
  _run_git(
    repo,
    'config',
    'remote.origin-https.fetch',
    '+refs/heads/*:refs/remotes/origin-https/*',
  )

  assert remote_urls_of(repo, Remote.HTTPS) == []
  assert 'origin-https' in declared_remotes_of(repo)


def test_every_url_of_a_remote_is_reported(tmp_path: Path) -> None:
  repo = tmp_path / 'multiurl'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'git@github.com:ishermandom/beta.git'
  )
  _run_git(
    repo,
    'config',
    '--add',
    'remote.origin.url',
    'https://gitlab.com/team/thing.git',
  )

  assert remote_urls_of(repo, Remote.SSH) == [
    'git@github.com:ishermandom/beta.git',
    'https://gitlab.com/team/thing.git',
  ]


def test_an_unreadable_config_is_not_reported_as_a_urlless_remote(
  tmp_path: Path,
) -> None:
  repo = tmp_path / 'broken-config'
  _make_repository(repo)
  _corrupt_config(repo)

  with pytest.raises(UnreadableRepository, match='origin'):
    remote_urls_of(repo, Remote.SSH)


def test_an_unreadable_config_is_not_reported_as_no_remotes(
  tmp_path: Path,
) -> None:
  repo = tmp_path / 'broken-config'
  _make_repository(repo)
  _corrupt_config(repo)

  with pytest.raises(UnreadableRepository, match='remotes'):
    declared_remotes_of(repo)


def test_an_unreadable_config_is_not_reported_as_an_absent_include(
  tmp_path: Path,
) -> None:
  # Reading no includes would wire a second copy of one that is already there.
  repo = tmp_path / 'broken-config'
  _make_repository(repo)
  _corrupt_config(repo)

  with pytest.raises(UnreadableRepository, match='includes'):
    is_already_wired(repo)


# --- scan_repositories ---


def test_a_plain_checkout_is_returned(tmp_path: Path) -> None:
  _make_repository(tmp_path / 'solo')

  assert scan_repositories(tmp_path).checkouts == [tmp_path / 'solo']


def test_a_checkout_reached_through_a_symlink_is_returned(
  tmp_path: Path,
) -> None:
  # git reports its paths resolved, so an unresolved shared directory would make
  # every plain checkout here look like a worktree owned from somewhere else.
  real = tmp_path / 'real'
  real.mkdir()
  _make_repository(real / 'solo')
  linked = tmp_path / 'linked'
  linked.symlink_to(real)

  assert scan_repositories(linked).checkouts == [real / 'solo']


def test_a_directory_that_is_not_a_checkout_is_ignored(tmp_path: Path) -> None:
  (tmp_path / 'not-a-repo').mkdir()

  assert scan_repositories(tmp_path).checkouts == []


def test_a_checkout_git_cannot_read_is_counted_as_unreadable(
  tmp_path: Path,
) -> None:
  # An empty `.git` is not a valid gitfile, so git refuses to inspect the
  # directory at all.
  broken = tmp_path / 'broken'
  broken.mkdir()
  (broken / '.git').touch()

  scan = scan_repositories(tmp_path)

  assert scan.checkouts == []
  assert scan.unreadable_repos == ['broken']


def test_worktrees_collapse_onto_the_checkout_owning_the_config(
  tmp_path: Path,
) -> None:
  main_checkout = tmp_path / 'main-repo'
  _make_repository(main_checkout)
  worktree = tmp_path / 'a-worktree'
  _run_git(main_checkout, 'worktree', 'add', '-q', str(worktree), '-b', 'side')

  # Two checkouts, one config, so one entry — named for the owning checkout.
  assert scan_repositories(tmp_path).checkouts == [main_checkout]


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

  scan = scan_repositories(tmp_path)

  assert scan.checkouts == []
  assert scan.foreign_worktrees == ['a-worktree']


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

  scan = scan_repositories(shared)

  assert scan.checkouts == []
  assert scan.foreign_worktrees == ['a-worktree']


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


def test_the_wired_include_selects_this_accounts_remote(tmp_path: Path) -> None:
  # What the whole script exists for: git must resolve the branch's remote
  # through the include, outranking the value `git clone` wrote into the repo's
  # own config.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  account_remote_file.write_text('[branch "main"]\n\tremote = origin-https\n')
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/ishermandom/bridge.git'
  )
  _run_git(repo, 'config', 'branch.main.remote', 'origin')

  main([], shared_code_dir=shared, account_remote_file=account_remote_file)

  assert _branch_remote(repo, 'main') == 'origin-https'


def test_an_already_correct_repository_still_gets_the_include(
  tmp_path: Path,
) -> None:
  # The state install.sh meets on the second account: both remotes already
  # canonical from the first account's run, the include not yet written.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'git@github.com:ishermandom/bridge.git'
  )
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
  assert _include_paths(repo) == [ACCOUNT_REMOTE_INCLUDE]
  assert _remote_url(repo, 'origin') == 'git@github.com:ishermandom/bridge.git'


def test_a_remote_declared_without_a_url_is_repaired(tmp_path: Path) -> None:
  # The remote exists but holds no URL, so it must be repointed rather than
  # added — and must not be read as pointing somewhere unmanaged.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'git@github.com:ishermandom/bridge.git'
  )
  _run_git(
    repo,
    'config',
    'remote.origin-https.fetch',
    '+refs/heads/*:refs/remotes/origin-https/*',
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  assert exit_code == 0
  assert _remote_url(repo, 'origin-https') == (
    'https://github.com/ishermandom/bridge.git'
  )
  assert _include_paths(repo) == [ACCOUNT_REMOTE_INCLUDE]


def test_a_remote_with_several_urls_survives_a_full_run(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  # The first URL alone looks perfectly canonical, so the second is the whole
  # risk: it must neither be dropped nor reported as configured.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'multiurl'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'git@github.com:ishermandom/beta.git'
  )
  _run_git(
    repo,
    'config',
    '--add',
    'remote.origin.url',
    'https://gitlab.com/team/thing.git',
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  output = capsys.readouterr()
  assert exit_code == 0
  assert _remote_urls(repo, 'origin') == [
    'git@github.com:ishermandom/beta.git',
    'https://gitlab.com/team/thing.git',
  ]
  assert _include_paths(repo) == []
  assert 'already matches' not in output.out


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


def test_an_include_spelled_absolutely_is_not_duplicated(
  tmp_path: Path,
) -> None:
  # The same file under another spelling. Matching on the exact string would
  # append a second entry here, and again on every later run.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'git@github.com:ishermandom/bridge.git'
  )
  _run_git(
    repo,
    'config',
    '--local',
    '--add',
    'include.path',
    str(account_remote_file),
  )

  main([], shared_code_dir=shared, account_remote_file=account_remote_file)

  assert _include_paths(repo) == [str(account_remote_file)]


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


def test_a_repository_left_alone_is_never_reported_as_matching(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  # Nothing changed and nothing failed, but the all-clear speaks for every repo
  # in the tree — and this one demonstrably does not match.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  repo = shared / 'theirs'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/someone-else/thing.git'
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  output = capsys.readouterr()
  assert exit_code == 0
  assert 'already matches' not in output.out
  assert 'theirs' in output.out


def test_a_worktree_owned_from_outside_is_reported_as_a_choice(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  # Left alone deliberately, so it belongs on stdout with the other skips —
  # stderr would read as a run that hit a problem.
  shared, account_remote_file = _make_shared_tree(tmp_path)
  outside = tmp_path / 'outside'
  outside.mkdir()
  main_checkout = outside / 'main-repo'
  _make_repository(main_checkout)
  _run_git(
    main_checkout,
    'worktree',
    'add',
    '-q',
    str(shared / 'a-worktree'),
    '-b',
    'side',
  )

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  output = capsys.readouterr()
  assert exit_code == 0
  assert 'left alone' in output.out
  assert 'already matches' not in output.out
  assert output.err == ''


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


def test_a_missing_account_remote_file_stops_the_run(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  shared, _ = _make_shared_tree(tmp_path)

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=tmp_path / 'absent'
  )

  assert exit_code == 1
  assert 'install.sh' in capsys.readouterr().err


def test_a_dry_run_previews_without_the_account_remote_file(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  # stow's own dry run never creates the file, so install.sh -n must still work.
  shared, _ = _make_shared_tree(tmp_path)
  repo = shared / 'bridge'
  _make_repository(repo)
  _run_git(
    repo, 'remote', 'add', 'origin', 'https://github.com/ishermandom/bridge.git'
  )

  exit_code = main(
    ['-n'], shared_code_dir=shared, account_remote_file=tmp_path / 'absent'
  )

  output = capsys.readouterr()
  assert exit_code == 0
  assert 'previewing' in output.out
  assert _include_paths(repo) == []


def test_a_missing_shared_directory_fails_the_run(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  _, account_remote_file = _make_shared_tree(tmp_path)

  exit_code = main(
    [],
    shared_code_dir=tmp_path / 'absent',
    account_remote_file=account_remote_file,
  )

  assert exit_code == 1
  assert 'absent' in capsys.readouterr().err


def test_a_dry_run_still_needs_the_shared_directory(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  # Unlike a missing account-remote file, which a preview tolerates because
  # stow's own dry run never creates it, nothing about a dry run explains a
  # shared directory that isn't there.
  _, account_remote_file = _make_shared_tree(tmp_path)

  exit_code = main(
    ['-n'],
    shared_code_dir=tmp_path / 'absent',
    account_remote_file=account_remote_file,
  )

  output = capsys.readouterr()
  assert exit_code == 1
  assert 'absent' in output.err
  assert 'dry run' not in output.out


def test_a_checkout_git_cannot_read_fails_the_run(
  tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
  shared, account_remote_file = _make_shared_tree(tmp_path)
  broken = shared / 'broken'
  broken.mkdir()
  (broken / '.git').touch()

  exit_code = main(
    [], shared_code_dir=shared, account_remote_file=account_remote_file
  )

  output = capsys.readouterr()
  assert exit_code == 1
  assert 'broken' in output.err
  # A failed run must not also claim that everything already matched.
  assert 'already matches' not in output.out
