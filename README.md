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

Both accounts on this machine share one working copy of this repo but reach
GitHub over different transports, so each account's remote choice lives in
`accounts/<account>/git/.config/git/dotfiles-remote` instead of `.git/config`.
Since `.git/config` is untracked, a fresh clone needs the include wired once:

```bash
git config --local include.path '~/.config/git/dotfiles-remote'
```

Keep the path single-quoted so Git stores a literal `~` and expands it per
account at read time — that is what lets one shared file serve both accounts.
