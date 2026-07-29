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

Both accounts on this machine share the working copies under
`/Users/Shared/code`, but reach GitHub over different transports: one over ssh
(`origin`), the other over https (`origin-https`). Each account's choice lives
in `accounts/<account>/git/.config/git/account-remote`, stowed to
`~/.config/git/account-remote`.

That file can't simply be included from `~/.gitconfig`, because a repo's own
config outranks global config and `git clone` writes `branch.main.remote` into
it. Each shared repo's config includes the file directly instead, by a
`~`-relative path that resolves to whichever account is running. Wire them with:

```bash
./configure-account-remotes.sh        # -n to preview
```

Run it once per account, and again after cloning a repo that has both remotes.
It skips repos with a single transport, since those have no choice to make, and
reports any repo needing a first `git fetch` to populate its tracking refs.

The file this repo tracks is `~/.gitconfig` (in `git/`). The per-repo
`.git/config` that carries the include is a different file — it lives inside
git's own metadata directory, so no repo can track it, which is why wiring it is
a script rather than a stow package.
