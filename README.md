# dotfiles

This repo manages system configuration via symlinks, managed using GNU Stow.

## Structure

- `claude/` — Claude Code global config (settings, agents, commands, skills,
  etc.)
- `git/` — gitconfig
- `zsh/` — zshrc, aliases
- etc.

- Symlinks are managed via `install.sh` from repo root
- Runtime Claude data (history, cache) lives in ~/.claude/ but is NOT tracked
  here
