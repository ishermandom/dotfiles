#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

"""Gives every shared repo both remotes, and points each account at its own.

Both accounts on this machine share the working copies under
`/Users/Shared/code` but reach GitHub differently, so every repo carries both
transports under fixed names: `origin` over ssh for the main account,
`origin-https` for the sandbox, which holds no ssh key.

Selecting between them cannot be done in a per-account global file, because a
repo's own config outranks global config and `git clone` writes
`branch.main.remote` into it. Each repo's config includes
`~/.config/git/account-remote` instead, whose `~`-relative path resolves to the
running account's own stowed copy.

A missing or mis-pointed remote is corrected rather than reported: a GitHub URL
carries the owner and repo, so its counterpart follows mechanically. Only repos
owned by `REPO_OWNER` are touched, leaving a fork's upstream and anyone else's
repo alone.

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

SHARED_CODE_DIR = Path('/Users/Shared/code')
REPO_OWNER = 'ishermandom'
SSH_URL_PREFIX = 'git@github.com:'
HTTPS_URL_PREFIX = 'https://github.com/'

# The tilde stays literal in the config file: Git expands it per account when it
# reads the include, which is what lets one line serve both accounts.
ACCOUNT_REMOTE_INCLUDE = '~/.config/git/account-remote'


class SkipReason(StrEnum):
  """Why a repository is left untouched.

  A `StrEnum` so each member is its own message: the reason reads directly in
  output, with no lookup table to keep in step with the members.
  """

  NO_GITHUB_REMOTE = 'no GitHub remote to work from'
  UNRECOGNIZED_REMOTE = 'a remote points somewhere this does not manage'
  FOREIGN_OWNER = 'owned by another account'
  CONFLICTING_REMOTES = 'origin and origin-https name different repos'


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


def github_path_of(url: str) -> str | None:
  """The `owner/repo` a GitHub URL points at, in either transport form.

  Returns `None` for anything that is not a GitHub repository URL, including the
  empty string a missing remote yields.
  """
  for prefix in (SSH_URL_PREFIX, HTTPS_URL_PREFIX):
    if url.startswith(prefix):
      path = url[len(prefix) :].removesuffix('.git')
      break
  else:
    return None

  # A repository path is exactly `owner/repo`, both segments non-empty.
  owner, separator, repo = path.partition('/')
  if not owner or not separator or not repo or '/' in repo:
    return None
  return path


def plan_remotes(origin_url: str, https_url: str) -> RemotePlan:
  """Decides what a repository's two remotes should become.

  Both arguments are the repository's current URLs, empty when that remote is
  absent.
  """
  # A remote aimed somewhere other than GitHub belongs to a setup this script
  # knows nothing about, so the repository is left alone rather than having that
  # URL overwritten from its counterpart.
  for url in (origin_url, https_url):
    if url and not github_path_of(url):
      return RemotePlan(skip_reason=SkipReason.UNRECOGNIZED_REMOTE)

  owner_and_repo = github_path_of(origin_url) or github_path_of(https_url)
  if not owner_and_repo:
    return RemotePlan(skip_reason=SkipReason.NO_GITHUB_REMOTE)

  owner = owner_and_repo.partition('/')[0]
  if owner != REPO_OWNER:
    return RemotePlan(skip_reason=SkipReason.FOREIGN_OWNER, foreign_owner=owner)

  # Two remotes naming different repositories is a misconfiguration with no safe
  # resolution — correcting either one could be the wrong guess.
  https_path = github_path_of(https_url)
  if https_path and https_path != owner_and_repo:
    return RemotePlan(skip_reason=SkipReason.CONFLICTING_REMOTES)

  # `origin` must be the ssh remote. No credential store keys off an ssh URL, so
  # its exact form is safe to normalize.
  required_ssh_url = f'{SSH_URL_PREFIX}{owner_and_repo}.git'
  ssh_change = None if origin_url == required_ssh_url else required_ssh_url

  # `origin-https` must reach the same repository over https. One that already
  # does keeps its exact URL: `credential.useHttpPath` keys stored credentials
  # on the full path, so rewriting a working URL would break authentication.
  https_change = None
  if not https_url.startswith(HTTPS_URL_PREFIX):
    https_change = f'{HTTPS_URL_PREFIX}{owner_and_repo}.git'

  return RemotePlan(ssh_url=ssh_change, https_url=https_change)


def run_git(repo: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
  """Runs a git command inside `repo`, capturing its output."""
  return subprocess.run(
    ['git', '-C', str(repo), *arguments],
    capture_output=True,
    text=True,
    check=False,
  )


def remote_url_of(repo: Path, remote: str) -> str:
  """A remote's URL, empty when the repository has no such remote.

  `git remote get-url` rather than `git config --get`, which reports only the
  last of a multi-valued `remote.<name>.url`.
  """
  return run_git(repo, 'remote', 'get-url', remote).stdout.strip()


def repository_checkouts(shared_code_dir: Path) -> Sequence[Path]:
  """One checkout per repository under `shared_code_dir`.

  A worktree shares its parent's config, so worktrees collapse onto the checkout
  that owns that config and each repository is returned once. The owning
  checkout must itself be a direct child of `shared_code_dir` — the same repos a
  plain scan would find. A worktree owned from anywhere else is left out, so
  following one never reaches a repository that was not placed here.
  """
  if not shared_code_dir.is_dir():
    print(
      f'{shared_code_dir} does not exist, so no repos were configured',
      file=sys.stderr,
    )
    return []

  checkouts: dict[Path, Path] = {}
  for candidate in sorted(shared_code_dir.iterdir()):
    if not (candidate / '.git').exists():
      continue
    result = run_git(
      candidate, 'rev-parse', '--path-format=absolute', '--git-common-dir'
    )
    # Git refusing to inspect a checkout is worth saying out loud: dropping it
    # quietly would report success over a repo nobody configured.
    if result.returncode != 0:
      print(
        f'  {candidate.name}: git cannot read it: {result.stderr.strip()}',
        file=sys.stderr,
      )
      continue
    # The checkout owning the config is the parent of the common git dir, which
    # is the same answer whichever worktree we asked.
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
  return sorted(checkouts.values())


def set_remote_url(repo: Path, remote: str, url: str, current_url: str) -> bool:
  """Points a remote at a URL, creating the remote when it is absent.

  `current_url` is what the remote holds now, empty when it has none — passed in
  rather than re-read so that whether the remote exists is decided once.
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

  changed_repos: list[str] = []
  failed_repos: list[str] = []

  for repo in repository_checkouts(shared_code_dir):
    origin_url = remote_url_of(repo, 'origin')
    https_url = remote_url_of(repo, 'origin-https')
    plan = plan_remotes(origin_url, https_url)

    if plan.skip_reason:
      reason = describe_skip(plan.skip_reason, plan.foreign_owner)
      print(f'  {repo.name}: {reason}, left alone')
      continue

    # Each entry pairs the new URL with what the remote holds now, so the write
    # step never has to ask again whether the remote exists.
    pending_remotes = [
      (remote, new_url, current_url)
      for remote, new_url, current_url in (
        ('origin', plan.ssh_url, origin_url),
        ('origin-https', plan.https_url, https_url),
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
      set_remote_url(repo, remote, new_url, current_url)
      for remote, new_url, current_url in pending_remotes
    )
    if has_succeeded and needs_wiring:
      has_succeeded = wire_include(repo)
    (changed_repos if has_succeeded else failed_repos).append(repo.name)

  changed_verb = 'would change' if args.dry_run else 'changed'
  if changed_repos:
    print(f'{script_name}: {changed_verb}: {" ".join(changed_repos)}')
  else:
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
