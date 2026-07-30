# dotfiles

This repo manages system configuration via symlinks, managed using GNU Stow.

## Structure

- `accounts/` — per-account overlays, layered over the packages below
- `claude/` — Claude Code global config (CLAUDE.md, settings, rules, skills,
  hooks, scripts, docs)
- `git/` — gitconfig
- `zed/` — Zed editor settings, keymap, custom themes
- `zsh/` — zshrc, aliases
- etc.

- Symlinks are managed via `install.sh` from repo root
- Runtime Claude data (history, cache) lives in ~/.claude/ but is NOT tracked
  here

## Per-account configuration

Files under `accounts/<account>/` mirror the package layout and are stowed only
when `install.sh` runs as that account, layering over the shared packages.

### Git remotes

The two accounts reach GitHub over different transports, so every shared repo
carries both: `origin` over ssh and `origin-https` over https. Which one an
account uses lives in `accounts/<account>/git/.config/git/account-remote`,
stowed to `~/.config/git/account-remote`.

Each repo's own config includes that file, and `configure_account_remotes.py` is
what puts the include there and keeps the remotes themselves in line. Its
docstring covers the rest, including why the selection can't live in
`~/.gitconfig`. `install.sh` runs it after stowing, so account setup stays one
command; it also runs on its own, which is what you want after cloning a repo:

```bash
./configure_account_remotes.py        # -n to preview
```

Wiring is a script rather than another stow package because `.git/config` is
per-clone state: Git creates it and writes that clone's own remotes and branches
into it, so it can't be a shared file linked from here.
