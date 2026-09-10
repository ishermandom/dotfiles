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
accounts can read and write. Model weights, corpora, and LLM tooling follow the
layout in `shared-storage.md` (owned by `ishermandom`, read-only for the
sandbox). Everything else in each account's home directory is inaccessible to
the other at the OS level.

## Sandbox constraints

`claude-sandbox` is a standard (non-admin) macOS user account. This means:

- Cannot install system software or modify system directories
- Cannot access `~/ishermandom/` (home dir, keychain, browser state, etc.)
- Can install launchd agents and cron jobs scoped to its own user
- Has unrestricted outbound network access (no firewall configured)
- Has push access to specific GitHub repos via fine-grained personal access
  tokens; branch protection rules on those repos prevent force pushes and branch
  deletions

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
`/Users/Shared/code/dotfiles/`, which makes the config versionable and editable
from either account.

Symlinked entries (resolve before editing — the Edit tool refuses to write
through symlinks):

| `~/.claude/` entry | Real path                                          |
| ------------------ | -------------------------------------------------- |
| `settings.json`    | `/Users/Shared/code/dotfiles/claude/settings.json` |
| `CLAUDE.md`        | `/Users/Shared/code/dotfiles/claude-md/CLAUDE.md`  |
| `docs/`            | `/Users/Shared/code/dotfiles/claude/docs/`         |
| `hooks/`           | `/Users/Shared/code/dotfiles/claude/hooks/`        |
| `rules/`           | `/Users/Shared/code/dotfiles/claude/rules/`        |
| `scripts/`         | `/Users/Shared/code/dotfiles/claude/scripts/`      |
| `skills/`          | `/Users/Shared/code/dotfiles/claude/skills/`       |

Everything else in `~/.claude/` (sessions, history, projects, plugins, cache,
etc.) is unversioned local state owned by Claude Code itself.

Project-level `.claude/` directories are not systematically gitignored. Whether
to commit them is decided per-project. Configuration that should persist across
machines belongs in `settings.json` above (and by extension the dotfiles repo).

## How sessions typically run

The user is logged into the primary account and enters the sandbox through
`claudify`, which opens an ssh connection to `claude-sandbox@localhost` and
starts a login shell in `/Users/Shared/code`. Protection is effectively
one-directional: `claude-sandbox` cannot escalate into `ishermandom`, but
`ishermandom` can freely access `claude-sandbox`'s files if needed.

### Backgrounding and the bootstrap namespace {#session-backgrounding}

Backgrounding a session hands it to a spare host process from the pool Claude
Code keeps under `/tmp/cc-daemon-505/`. That spare inherits the daemon's
bootstrap namespace rather than the shell's, so the boundary a backgrounded
session sits behind is set by wherever the daemon was first started — not by
where the session itself began. A daemon rooted in an `Aqua` context, such as an
earlier `sudo -u` entry point, goes on handing out that namespace for as long as
it lives, outliving the entry point that created it.

Nothing enforces the ssh ancestry, and a session that has drifted keeps working
normally. Only `launchctl managername` says otherwise, so check it after
backgrounding rather than before.

### Terminal capabilities over ssh {#terminfo}

Ghostty sets `TERM=xterm-ghostty` and ships that terminfo entry only inside its
own app bundle. The sandbox account has no copy of its own, so a session there
cannot load the terminal's capabilities, and the shell prompt renders without
color. Install the entry once per account:

```sh
infocmp -x -A /Applications/Ghostty.app/Contents/Resources/terminfo \
  xterm-ghostty | tic -x -o ~/.terminfo -
```

Ghostty can also install terminfo on a remote host itself, through the
`ssh-terminfo` shell-integration feature that ships disabled. That route hooks
the `ssh` command from an interactive shell, so whether it reaches `claudify` —
a script making its own `ssh` call — is worth testing before relying on it.

### Copying text out of a session {#clipboard}

Claude Code detects the ssh connection and writes the clipboard as an OSC 52
escape sequence instead of calling `pbcopy`. That suits the account split: the
sandbox has no pasteboard server of its own, and a `pbcopy` there would address
a pasteboard nothing ever reads. The sequence rides the existing connection and
is handled by the terminal on the primary account, so copied text reaches
`ishermandom`'s pasteboard without any bridge between the two accounts.

The terminal emulator is therefore load-bearing, and has to implement OSC 52.
Terminal.app does not — it discards the sequence silently, so a copy from inside
a session reaches nothing at all. Ghostty handles it, with `clipboard-write`
defaulting to `allow`; its `clipboard-read` defaults to `ask`, which leaves the
direction this threat model cares about behind a prompt.
