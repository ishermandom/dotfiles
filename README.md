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

#### Discarded: two remotes selected by an include

The approach above is discarded in favour of per-account URL rewriting —
`url.<base>.insteadOf` in each account's `~/.gitconfig.local`, rewriting GitHub
URLs to the transport that account can actually reach. That needs no per-repo
configuration at all: a fresh clone works with no post-clone step, and nothing
in a shared repo's config has to differ between accounts. The switch has not
landed yet, so the mechanism described above is still what runs today.

The two-remote mechanism was last seen in full at commit `2bdfdf5`. Reviving it
would need a full re-review first: much of it changed after its last review, and
the state at that commit carried one automated review round and no line-by-line
human review.

TODO: remove this subsection after 2027-01-01 — going that long without needing
it is good evidence that the simpler approach is sufficient and no change is
warranted.
