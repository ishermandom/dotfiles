#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

"""Configures git remotes for all of my repos.

Both accounts on this machine share the working copies under
`/Users/Shared/code` but reach GitHub differently, so every repo carries both
transports under fixed names: `origin` over ssh for the main account,
`origin-https` for the sandbox, which holds no ssh key. Gives every shared repo
both remotes, and points each account at its own.

Selecting between them cannot be done in a per-account global file, because a
repo's own config outranks global config and `git clone` writes
`branch.main.remote` into it. Each repo's config includes
`~/.config/git/account-remote` instead, whose `~`-relative path resolves to the
running account's own stowed copy.

A missing or mis-pointed remote is corrected rather than reported: a GitHub URL
carries the owner and repo, so its counterpart follows mechanically. Only repos
owned by `REPO_OWNER` are touched, leaving a fork's upstream and anyone else's
repo alone.

Selecting a remote does not create its tracking refs — those arrive on the first
successful fetch, so until then `git status` shows no upstream. That goes
unreported: an account may have no credentials stored for a repo it never
fetches, where the state is permanent and correct rather than a pending chore.

install.sh runs this after stowing. Run it directly after cloning a repo.
Re-running is harmless.
"""

import argparse
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

# Output is plain `print`, not `logging`: every line is part of one run's report
# to whoever invoked it, interleaved with install.sh's own echoes, and none of
# it wants levels, timestamps, or a file of its own. Failures go to stderr.

SHARED_CODE_DIR = Path('/Users/Shared/code')
REPO_OWNER = 'ishermandom'
SSH_URL_PREFIX = 'git@github.com:'
HTTPS_URL_PREFIX = 'https://github.com/'

# The tilde stays literal in the config file: Git expands it per account when it
# reads the include, which is what lets one line serve both accounts.
ACCOUNT_REMOTE_INCLUDE = '~/.config/git/account-remote'


class Remote(StrEnum):
  """The two remote names every shared repo carries, one per transport."""

  SSH = 'origin'
  HTTPS = 'origin-https'


@dataclass(frozen=True)
class GitHubRepository:
  """Which repository a remote names — the one thing both URL forms agree on.

  Equality is therefore the test for whether two remotes point at the same
  repository.
  """

  owner: str
  name: str

  @property
  def ssh_url(self) -> str:
    """The ssh URL `origin` must point at."""
    return f'{SSH_URL_PREFIX}{self.owner}/{self.name}.git'

  @property
  def https_url(self) -> str:
    """The https URL `origin-https` is given when it has none that works."""
    return f'{HTTPS_URL_PREFIX}{self.owner}/{self.name}.git'


class SkipReason(StrEnum):
  """Why a repository is left untouched.

  A `StrEnum` so each member is its own message: the reason reads directly in
  output, with no lookup table to keep in step with the members.
  """

  UNRECOGNIZED_REMOTE = 'a remote points somewhere this does not manage'
  CONFLICTING_REMOTES = 'origin and origin-https name different repos'
  MISSING_BOTH_REMOTES = 'neither origin nor origin-https exists'
  FOREIGN_OWNER = 'owned by another account'


@dataclass(frozen=True)
class RemotePlan:
  """What a repository's remotes should become.

  A `skip_reason` means the repository is left alone and the URL fields are
  unset. Otherwise a `None` URL means that remote is already correct.
  """

  skip_reason: SkipReason | None = None
  foreign_owner: str | None = None
  ssh_url: str | None = None
  https_url: str | None = None


def github_repository_of(url: str) -> GitHubRepository | None:
  """The repository a GitHub URL names, in either transport form.

  Returns `None` for anything that is not a GitHub repository URL, including the
  empty string a missing remote yields.
  """
  for prefix in (SSH_URL_PREFIX, HTTPS_URL_PREFIX):
    if url.startswith(prefix):
      path = url[len(prefix) :].removesuffix('.git')
      break
  else:
    return None

  # A repository path is exactly `owner/repo`, both segments non-empty. An
  # absent separator leaves the name empty, so that case needs no test of its
  # own.
  owner, _, name = path.partition('/')
  if not owner or not name or '/' in name:
    return None
  return GitHubRepository(owner=owner, name=name)


def plan_remotes(*, origin_url: str, https_url: str) -> RemotePlan:
  """Decides what a repository's two remotes should become.

  Both arguments are the repository's current URLs, empty when that remote is
  absent. Keyword-only, since two URLs in either order type-check equally well
  and a swap would silently plan each remote against the other's state.
  """
  origin_repository = github_repository_of(origin_url)
  https_repository = github_repository_of(https_url)

  # A remote aimed somewhere other than GitHub belongs to a setup this script
  # knows nothing about, so the repository is left alone rather than having that
  # URL overwritten from its counterpart.
  if (origin_url and not origin_repository) or (
    https_url and not https_repository
  ):
    return RemotePlan(skip_reason=SkipReason.UNRECOGNIZED_REMOTE)

  # Two remotes naming different repositories leaves no safe correction: which
  # repository this is has no answer here, so repointing either could be the
  # wrong guess. Asked before the owner, which that ambiguity would also make
  # unanswerable.
  if (
    origin_repository
    and https_repository
    and origin_repository != https_repository
  ):
    return RemotePlan(skip_reason=SkipReason.CONFLICTING_REMOTES)

  # Past those guards an unparsed URL means only an absent remote, and either
  # remote alone identifies the repository — so one is enough to build both
  # from.
  repository = origin_repository or https_repository
  if not repository:
    return RemotePlan(skip_reason=SkipReason.MISSING_BOTH_REMOTES)

  if repository.owner != REPO_OWNER:
    return RemotePlan(
      skip_reason=SkipReason.FOREIGN_OWNER, foreign_owner=repository.owner
    )

  # `origin` must be the ssh remote. Nothing keys off an ssh URL the way
  # `credential.useHttpPath` keys off an https one, so its exact form is safe to
  # normalize.
  ssh_change = None if origin_url == repository.ssh_url else repository.ssh_url

  # `origin-https` need only reach the same repository over https. One that
  # already does keeps its exact URL rather than being normalized like the ssh
  # side: `credential.useHttpPath` keys stored credentials on the full path, so
  # rewriting a working URL would break authentication.
  reaches_over_https = https_url.startswith(HTTPS_URL_PREFIX)
  https_change = None if reaches_over_https else repository.https_url

  return RemotePlan(ssh_url=ssh_change, https_url=https_change)


def run_git(repo: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
  """Runs a git command inside `repo`, capturing its output."""
  return subprocess.run(
    ['git', '-C', str(repo), *arguments],
    capture_output=True,
    text=True,
    check=False,
  )


def remote_url_of(repo: Path, remote: Remote) -> str:
  """A remote's URL, empty when the repository has no such remote.

  `git remote get-url` rather than `git config --get`, which reports only the
  last of a multi-valued `remote.<name>.url`.
  """
  return run_git(repo, 'remote', 'get-url', remote).stdout.strip()


@dataclass(frozen=True)
class RepositoryScan:
  """What a scan of the shared code directory found.

  `unreadable_repos` holds the names of checkouts git refused to inspect. They
  are failures rather than skips: a repo nobody can configure is a problem, not
  a choice.
  """

  checkouts: Sequence[Path]
  unreadable_repos: Sequence[str]


def scan_repositories(shared_code_dir: Path) -> RepositoryScan:
  """One checkout per repository under `shared_code_dir`, alphabetically.

  A worktree shares its parent's config, so worktrees collapse onto the checkout
  that owns that config and each repository is returned once. The owning
  checkout must itself be a direct child of `shared_code_dir` — the same repos a
  plain scan would find. A worktree owned from anywhere else is left out, so
  following one never reaches a repository that was not placed here.

  Alphabetical rather than the order found: collapsing can surface a checkout
  before its own name comes up in the scan. The run's report follows this order,
  so it should be the one a reader expects.

  Raises `FileNotFoundError` when `shared_code_dir` does not exist. `main`
  checks for that first, so the run can report it and exit non-zero.
  """
  checkouts: dict[Path, Path] = {}
  unreadable_repos: list[str] = []
  for candidate in sorted(shared_code_dir.iterdir()):
    if not (candidate / '.git').exists():
      continue
    result = run_git(
      candidate, 'rev-parse', '--path-format=absolute', '--git-common-dir'
    )
    # A checkout git cannot read counts as a failure, not a skip: reporting
    # success over a repo nobody configured would bury it.
    if result.returncode != 0:
      print(
        f'  {candidate.name}: git cannot read it: {result.stderr.strip()}',
        file=sys.stderr,
      )
      unreadable_repos.append(candidate.name)
      continue
    # `--git-common-dir` is the `.git` directory holding the config a checkout
    # reads, which for a worktree is the main checkout's: asked inside the
    # worktree `code/bridge-fix`, it answers `code/bridge/.git`, whose parent
    # `code/bridge` is the checkout that owns it. A plain checkout answers with
    # its own `.git`, and so maps to itself.
    common_dir = Path(result.stdout.strip())
    owning_checkout = common_dir.parent
    if owning_checkout.parent != shared_code_dir:
      print(
        f'  {candidate.name}: a worktree of {owning_checkout}, which is not a '
        f'repo directly under {shared_code_dir}, left alone',
        file=sys.stderr,
      )
      continue
    checkouts.setdefault(common_dir, owning_checkout)

  return RepositoryScan(
    checkouts=sorted(checkouts.values()), unreadable_repos=unreadable_repos
  )


def set_remote_url(
  repo: Path, remote: Remote, *, url: str, current_url: str
) -> bool:
  """Points a remote at a URL, creating the remote when it is absent.

  `current_url` is what the remote holds now, empty when it has none — passed in
  rather than re-read so that whether the remote exists is decided once. The two
  URLs are keyword-only: in either order they type-check equally well, and a
  swap would point the remote at the URL it already holds.
  """
  subcommand = 'set-url' if current_url else 'add'
  result = run_git(repo, 'remote', subcommand, remote, url)
  if result.returncode != 0:
    print(
      f'  {repo.name}: git remote {subcommand} failed: {result.stderr.strip()}',
      file=sys.stderr,
    )
    return False
  return True


def is_already_wired(repo: Path) -> bool:
  """Whether the repository's own config already carries the include."""
  result = run_git(repo, 'config', '--local', '--get-all', 'include.path')
  return ACCOUNT_REMOTE_INCLUDE in result.stdout.splitlines()


def wire_include(repo: Path) -> bool:
  """Adds the account-remote include to the repository's own config."""
  result = run_git(
    repo, 'config', '--local', '--add', 'include.path', ACCOUNT_REMOTE_INCLUDE
  )
  if result.returncode != 0:
    print(
      f'  {repo.name}: could not add the include: {result.stderr.strip()}',
      file=sys.stderr,
    )
    return False
  return True


def describe_skip(reason: SkipReason, foreign_owner: str | None) -> str:
  """The human-readable reason a repository was left alone."""
  if reason is SkipReason.FOREIGN_OWNER:
    return f'owned by {foreign_owner}'
  return reason


def default_account_remote_file() -> Path:
  """Where this account's stowed copy of the remote selection lives."""
  return Path.home() / '.config/git/account-remote'


def main(
  argv: Sequence[str] | None = None,
  shared_code_dir: Path = SHARED_CODE_DIR,
  account_remote_file: Path | None = None,
) -> int:
  """Configures remotes and the include for every shared repository.

  The two paths are parameters rather than flags so tests can drive the whole
  run against a temporary tree, without offering a way to aim a repo-writing
  script at an arbitrary directory from the command line.
  """
  parser = argparse.ArgumentParser(
    description="Point every shared repo at this account's Git remote."
  )
  parser.add_argument(
    '-n',
    '--dry-run',
    action='store_true',
    help='report what would change without modifying anything',
  )
  args = parser.parse_args(argv)
  script_name = parser.prog

  # Nothing can be configured without the directory the repos live in, and,
  # unlike the account-remote file below, a dry run has no reason to be lenient
  # about it.
  if not shared_code_dir.is_dir():
    print(f'{script_name}: {shared_code_dir} does not exist', file=sys.stderr)
    return 1

  # The include stays inert until this account's own copy of the file exists, so
  # a missing one means the stow packages haven't been installed here yet.
  account_remote_file = account_remote_file or default_account_remote_file()
  if not account_remote_file.exists():
    missing = f'{script_name}: {account_remote_file} is missing'
    # A preview runs anyway: stow's own dry run never creates the file, so
    # failing here would make `install.sh -n` fail on a fresh account.
    if not args.dry_run:
      print(f'{missing} — run ./install.sh', file=sys.stderr)
      return 1
    print(f'{missing}; previewing against it anyway')

  if args.dry_run:
    print(f'{script_name}: dry run, nothing will be modified')

  scan = scan_repositories(shared_code_dir)
  changed_repos: list[str] = []
  # A checkout git could not read never reaches the loop, so it starts out
  # counted among the failures.
  failed_repos: list[str] = list(scan.unreadable_repos)

  for repo in scan.checkouts:
    origin_url = remote_url_of(repo, Remote.SSH)
    https_url = remote_url_of(repo, Remote.HTTPS)
    plan = plan_remotes(origin_url=origin_url, https_url=https_url)

    if plan.skip_reason:
      reason = describe_skip(plan.skip_reason, plan.foreign_owner)
      print(f'  {repo.name}: {reason}, left alone')
      continue

    # Each entry pairs the new URL with what the remote holds now, so the write
    # step never has to ask again whether the remote exists.
    pending_remotes = [
      (remote, new_url, current_url)
      for remote, new_url, current_url in (
        (Remote.SSH, plan.ssh_url, origin_url),
        (Remote.HTTPS, plan.https_url, https_url),
      )
      if new_url
    ]
    needs_wiring = not is_already_wired(repo)
    if not pending_remotes and not needs_wiring:
      continue

    for remote, new_url, _ in pending_remotes:
      print(f'  {repo.name}: {remote} -> {new_url}')
    if needs_wiring:
      print(f'  {repo.name}: include -> {ACCOUNT_REMOTE_INCLUDE}')

    if args.dry_run:
      changed_repos.append(repo.name)
      continue

    # `all` short-circuits, so a failed write stops the rest for this repo.
    has_succeeded = all(
      set_remote_url(repo, remote, url=new_url, current_url=current_url)
      for remote, new_url, current_url in pending_remotes
    )
    if has_succeeded and needs_wiring:
      has_succeeded = wire_include(repo)
    (changed_repos if has_succeeded else failed_repos).append(repo.name)

  changed_verb = 'would change' if args.dry_run else 'changed'
  if changed_repos:
    print(f'{script_name}: {changed_verb}: {" ".join(changed_repos)}')
  elif not failed_repos:
    print(f'{script_name}: every repo already matches')

  if failed_repos:
    print(
      f'{script_name}: could not configure (see errors above): '
      f'{" ".join(failed_repos)}',
      file=sys.stderr,
    )
    return 1
  return 0


if __name__ == '__main__':
  sys.exit(main())
