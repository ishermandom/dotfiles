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
- Holds Screen Recording for `Terminal.app`, which is what lets Claude see this
  account's desktop — see #display-access
- Must never hold Accessibility, Input Monitoring or Full Disk Access — see
  #system-tcc

### The system permission database {#system-tcc}

macOS keeps two permission databases, and only one of them respects the account
boundary. The per-user database at
`~/Library/Application Support/com.apple.TCC/TCC.db` holds camera, microphone,
screen recording and Apple events, and binds each grant to the account that made
it. The system database at `/Library/Application Support/com.apple.TCC/TCC.db`
holds Accessibility, Input Monitoring and Full Disk Access, takes admin
authentication to change, and attaches each grant to an application machine-wide
rather than to the granting account.

A system-database grant made here is therefore not contained by `claude-sandbox`
at all. Measured on 2026-09-22 under macOS 26.6.2: with Accessibility granted to
`Terminal.app` in this account, a probe was able to read the accessibility trees
of `ishermandom`'s app windows running in their separate login session. The same
danger is documented for Full Disk Access, where one admin granting it to
Terminal hands it to every account on the machine.

The account boundary holds for everything outside this class, and the class is
short enough to name in full: Accessibility, Input Monitoring, Full Disk Access.

## Threat model and coverage

| Threat                                 | Coverage               | Notes                                                                                                                                                                             |
| -------------------------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Wipe or corrupt primary account files  | ✅ Protected           | OS account separation; claude-sandbox cannot reach `~/ishermandom/`                                                                                                               |
| Runaway Claude API spend               | ✅ Protected           | Subscription plan has automatic usage caps                                                                                                                                        |
| Other API/cloud spend                  | ✅ Protected           | Other credentials live only in primary account                                                                                                                                    |
| Force-push or delete GitHub branches   | ✅ Protected           | GitHub branch protection rules block these                                                                                                                                        |
| Wipe `/Users/Shared/code`              | ⚠️ Partially mitigated | Git history + Claude Code destructive-command hooks help; raw `rm -rf` bypasses hooks. Remotes are the backstop for content; the local repo itself is not independently backed up |
| Secret exfiltration via network        | ⚠️ Policy-based        | No secrets are intentionally stored in `/Users/Shared/code`, but this isn't technically enforced or audited                                                                       |
| Persistence across reboots             | ⚠️ Known gap           | `claude-sandbox` can install launchd agents or cron jobs under its own user without admin; not currently monitored                                                                |
| Malicious commits pushed to GitHub     | ⚠️ Partially mitigated | Fine-grained tokens limit scope; branch protection prevents the worst outcomes, but legitimate-looking commits could still be pushed                                              |
| Read or drive the primary account's UI | ⚠️ Policy-based        | Holds only while no system-database permission is granted here; see #system-tcc                                                                                                   |

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

### Seeing this account's display {#display-access}

`claude-sandbox` has its own Aqua login session, kept alive by fast user
switching, and that session has a framebuffer of its own:
`CGGetActiveDisplayList` reports a display there even while `ishermandom` owns
`/dev/console` and nobody is connected to it. What an ssh session lacks is
placement in that session — it lands in the `Background` domain, which has no
window server connection, so `screencapture` fails there with "could not create
image from display" however the permissions are set.

`open -a Terminal <script>` bridges the gap. The script runs with
`launchctl managername` reporting `Aqua`, and macOS holds `Terminal.app`
responsible for what it does, which is what makes the Screen Recording grant
apply to it. Terminal is the right identity to hold that grant because it moves
only with macOS, where a third-party terminal's update could change its
signature and void the grant.

Capture is bounded by the login session, unlike the permissions in #system-tcc.
Enumerating on-screen windows from the sandbox account lists only windows owned
by `claude-sandbox`, and a full-screen capture shows the sandbox account's
desktop rather than the primary account's. Driving that desktop is a different
matter: synthetic clicks and keystrokes need Accessibility, which #system-tcc
rules out. Automation might still drive a specific scriptable app without it,
since it is granted per source-and-target app pair and lives in the per-user
database — though whether Apple events stay inside a login session was never
measured, and the same guess about Accessibility proved wrong.

### Terminal capabilities over ssh {#terminfo}

Ghostty sets `TERM=xterm-ghostty` and ships that terminfo entry only inside its
own app bundle. It points its own shells at the bundle through the `TERMINFO`
variable, but ssh does not carry that variable across, so a shell reached
through `claudify` cannot resolve the entry and renders its prompt without
color. `install.sh` links the bundle's entries into `~/.terminfo`, which
terminfo lookups search by default, so each account reads them straight from the
installed Ghostty.

Three alternatives fall short:

- **Setting `TERMINFO_DIRS` in a startup file** reaches the programs the shell
  starts, but never the shell's own prompt. macOS's ncurses settles its search
  path at a process's first terminfo lookup, and zsh makes that lookup at
  startup, before it reads `.zshenv` or `.zprofile`. Assigning the variable
  there makes zsh look again with the settled path, which fails with
  `can't find terminal definition`.
- **A compiled copy in `~/.terminfo`**, made with `infocmp` and `tic`, is found
  at startup but goes stale whenever Ghostty updates its entry.
- **Ghostty's `ssh-terminfo` feature** installs the entry on the remote host
  automatically, but it works by replacing `ssh` with a shell function, and a
  shell function is not inherited by child processes. `claudify` is a script
  that runs its own `ssh`, so the feature never sees it.

### Copying text out of a session {#clipboard}

Claude Code detects the ssh connection and writes the clipboard as an OSC 52
escape sequence instead of calling `pbcopy`. That suits the account split: a
`pbcopy` in the sandbox could reach at most the sandbox account's own
pasteboard, which nothing on the primary account reads. The sequence rides the
existing connection and is handled by the terminal on the primary account, so
copied text reaches `ishermandom`'s pasteboard without any bridge between the
two accounts.

The terminal emulator is therefore load-bearing, and has to implement OSC 52.
Terminal.app does not — it discards the sequence silently, so a copy from inside
a session reaches nothing at all. Ghostty handles it, with `clipboard-write`
defaulting to `allow`; its `clipboard-read` defaults to `ask`, which leaves the
direction this threat model cares about behind a prompt.

If Ghostty proves a poor fit, the planned fallback is Terminal.app with
osc52pty, which is not in use yet. osc52pty would wrap `claudify`'s ssh on the
primary account, strip each OSC 52 sequence from the session's output, and hand
the sequence's text to `pbcopy`. That works only while Claude Code sends the
sequence without first asking whether the terminal supports OSC 52, as 2.1.267
does.

The fallback would most likely use
[fortinmike's fork](https://github.com/fortinmike/osc52pty) rather than the
original, [roy2220/osc52pty](https://github.com/roy2220/osc52pty), whose author
has stepped back from it. As of v0.2.0, the original recognizes only BEL as a
terminator, so any sequence ending in ST (`ESC \`) swallows all later output
until some BEL arrives; Neovim's copies end that way. The fork handles both.

tmux falls short in either position:

- **On the primary account**, around `claudify`, tmux could pass each copy's
  text to `pbcopy` through its `pane-set-clipboard` hook. But that would make a
  large parser running as the primary account read everything the sandbox prints
  — too much weight, and so too much risk, for one escape sequence.
- **Inside the sandbox**, tmux passes each copy on as its own OSC 52 sequence,
  so the terminal still has to implement OSC 52. Beyond that, tmux offers no
  clear benefit here: Claude Code's background sessions already outlive a closed
  window, and Ghostty has native splits.

### Opening links from a session {#links}

Shift+Cmd+click opens a link in the primary account's browser. A plain click or
a Cmd+click does not: Claude Code's fullscreen mode tracks the mouse, so Ghostty
passes those clicks to Claude Code, which opens links from its own process in
the sandbox. Holding Shift makes Ghostty handle the click itself, on the primary
account.
