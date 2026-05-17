# macOS account setup

## Overview

Two macOS user accounts are in use:

- **`ishermandom`** — primary account for day-to-day work
- **`claude-sandbox`** — sandboxed account for CLI assistants (currently Claude
  Code; potentially others in future)

The sandbox account is designed to limit blast radius from destructive, costly,
or exfiltrating actions that a CLI assistant might take — whether by accident or
via prompt injection.

Code is shared between accounts via **`/Users/Shared/code`**, which both
accounts can read and write. Everything else in each account's home directory
is inaccessible to the other at the OS level.

## Sandbox constraints

`claude-sandbox` is a standard (non-admin) macOS user account. This means:

- Cannot install system software or modify system directories
- Cannot access `~/ishermandom/` (home dir, keychain, browser state, etc.)
- Can install launchd agents and cron jobs scoped to its own user
- Has unrestricted outbound network access (no firewall configured)
- Has push access to specific GitHub repos via fine-grained personal access
  tokens; branch protection rules on those repos prevent force pushes and
  branch deletions

## Threat model and coverage

| Threat                                | Coverage               | Notes                                                                                                                                                                             |
| ------------------------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Wipe or corrupt primary account files | ✅ Protected           | OS account separation; claude-sandbox cannot reach `~/ishermandom/`                                                                                                               |
| Runaway Claude API spend              | ✅ Protected           | Subscription plan has automatic usage caps                                                                                                                                        |
| Other API/cloud spend                 | ✅ Protected           | Other credentials live only in primary account                                                                                                                                    |
| Force-push or delete GitHub branches  | ✅ Protected           | GitHub branch protection rules block these                                                                                                                                        |
| Wipe `/Users/Shared/code`             | ⚠️ Partially mitigated | Git history + Claude Code destructive-command hooks help; raw `rm -rf` bypasses hooks. Remotes are the backstop for content; the local repo itself is not independently backed up |
| Secret exfiltration via network       | ⚠️ Policy-based        | No secrets are intentionally stored in `/Users/Shared/code`, but this isn't technically enforced or audited                                                                       |
| Persistence across reboots            | ⚠️ Known gap           | `claude-sandbox` can install launchd agents or cron jobs under its own user without admin; not currently monitored                                                                |
| Malicious commits pushed to GitHub    | ⚠️ Partially mitigated | Fine-grained tokens limit scope; branch protection prevents the worst outcomes, but legitimate-looking commits could still be pushed                                              |

## Claude configuration and dotfiles

Most Claude Code configuration lives globally in `~/.claude/` on the
`claude-sandbox` account, not in individual project directories. Several entries
in that directory are symlinks into a dotfiles repo at
`/Users/Shared/code/dotfiles/claude/`, which makes the config versionable and
editable from either account.

Symlinked entries (resolve before editing — the Edit tool refuses to write
through symlinks):

| `~/.claude/` entry | Real path                                          |
| ------------------ | -------------------------------------------------- |
| `settings.json`    | `/Users/Shared/code/dotfiles/claude/settings.json` |
| `CLAUDE.md`        | `/Users/Shared/code/dotfiles/claude/CLAUDE.md`     |
| `docs/`            | `/Users/Shared/code/dotfiles/claude/docs/`         |
| `rules/`           | `/Users/Shared/code/dotfiles/claude/rules/`        |
| `skills/`          | `/Users/Shared/code/dotfiles/claude/skills/`       |

Everything else in `~/.claude/` (sessions, history, projects, plugins, cache,
etc.) is unversioned local state owned by Claude Code itself.

Project-level `.claude/` directories are gitignored and not version controlled.
Configuration that should persist across machines belongs in `settings.json`
above (and by extension the dotfiles repo). Project-level files are reserved for
unusual per-project overrides that deliberately deviate from global
configuration.

## How sessions typically run

The user is logged into the primary account and invokes Claude Code from a
terminal running under `claude-sandbox` (e.g., via `su - claude-sandbox` or a
dedicated Terminal profile). Protection is effectively one-directional:
`claude-sandbox` cannot escalate into `ishermandom`, but `ishermandom` can
freely access `claude-sandbox`'s files if needed.
