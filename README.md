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
`~`-relative path that resolves to whichever account is running.

`install.sh` wires this after stowing, so account setup stays one command.
`configure_account_remotes.py` also runs on its own, which is what you want
after cloning a repo:

```bash
./configure_account_remotes.py        # -n to preview
```

Every repo carries both remotes under fixed names, and the script creates or
repoints one that is missing or aimed at the wrong transport — a GitHub URL
carries the owner and repo, so its counterpart follows mechanically. Repos owned
by anyone else are left alone, as is an https URL that already works, since
`credential.useHttpPath` keys stored credentials on the exact path.

Wiring is a script rather than another stow package because `.git/config` is
per-clone state: Git creates it and writes that clone's own remotes and branches
into it, so it can't be a shared file linked from here.
