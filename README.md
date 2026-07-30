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

The two accounts reach GitHub over different transports: `ishermandom` over ssh,
`claude-sandbox` over https, holding no ssh key. Each account's
`~/.gitconfig.local` rewrites a GitHub URL to the transport it can reach, using
`url.<base>.insteadOf`; those two files carry the rules and what they constrain.

A shared repo therefore records one ssh `origin` that both accounts read, needs
no per-account configuration of its own, and works straight out of a fresh clone
with no post-clone step. The rewrite changes the URL git connects with, not what
`git remote -v` prints — `git ls-remote --get-url origin` shows the one actually
used.

#### Discarded: two remotes selected by an include

Every shared repo used to carry both remotes — `origin` over ssh and
`origin-https` over https — and to include a per-account
`~/.config/git/account-remote` naming which one to use. Keeping that include and
those remotes in line took a dedicated script, `configure_account_remotes.py`,
run by `install.sh` after stowing and again by hand after each clone, because
`.git/config` is per-clone state that can't be a shared file linked from here.
URL rewriting reaches the same result with none of that machinery.

The mechanism was last seen in full at commit `2bdfdf5`. Reviving it would need
a full re-review first: much of it changed after its last review, and the state
at that commit carried one automated review round and no line-by-line human
review.

TODO: remove this subsection after 2027-01-01 — going that long without needing
it is good evidence that the simpler approach is sufficient and no change is
warranted.
