# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

# share_history writes each command immediately and imports new commands from
# other sessions before showing the prompt.
setopt share_history
setopt extended_history   # save timestamp and duration with each entry
setopt hist_ignore_dups   # skip consecutive duplicates
setopt hist_ignore_space  # commands prefixed with a space are not saved

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

# Prompt colors — edit these values to restyle. Use color names (red, blue,
# green, yellow, magenta, cyan, white) or 256-color indices (0–255).
_pc_path='81'   # cyan-blue
_pc_git='183'   # lavender
_pc_time='252'  # light gray
_pc_user='214'  # orange
_pc_ok='green'
_pc_err='red'

# Git branch and dirty indicator via vcs_info (built into zsh).
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' formats '%b%u'
zstyle ':vcs_info:git:*' actionformats '%b|%a%u'

setopt prompt_subst

_build_prompt() {
  local exit_code=$1

  # Show username when not the primary user; show hostname only over SSH.
  # Combined as user@host, user, or host as appropriate.
  local _user='' _host='' _sep=''
  [[ "$USER" != 'ishermandom' ]] && _user='%n'
  [[ -n "$SSH_CLIENT" ]] && _host='%m'
  [[ -n "$_user" && -n "$_host" ]] && _sep='@'
  local user_seg=''
  [[ -n "${_user}${_host}" ]] && user_seg="%F{$_pc_user}${_user}${_sep}${_host}%f "

  # Full path when ≤ 4 components deep; first-dir/…/last-two when deeper.
  # Outside the home directory, first-dir is a literal path segment, not ~.
  local path_seg="%F{$_pc_path}%(5~|%-1~/…/%2~|%~)%f"

  # Git segment is empty outside a repo.
  local git_seg=''
  [[ -n "$vcs_info_msg_0_" ]] && git_seg=" %F{$_pc_git}${vcs_info_msg_0_}%f"

  # Prompt char is green on success, red on failure.
  local char_color
  (( exit_code == 0 )) && char_color=$_pc_ok || char_color=$_pc_err

  PROMPT="%F{$_pc_time}%*%f ${user_seg}${path_seg}${git_seg}"$'\n'"%F{$char_color}\$%f "
}

precmd() {
  local exit_code=$?
  vcs_info
  _build_prompt $exit_code
}

alias ..='cd ..'
alias goto='pushd /Users/Shared/code'
alias architect='claude --model sonnet --effort high'

# Load zsh completions from Homebrew (includes native git completions).
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)
autoload -Uz compinit
# Homebrew completion files are owned by the primary user, so compinit's
# ownership check fails for sandbox accounts. -u skips it; safe here because
# all accounts on this machine are personally controlled.
if [[ "$USER" == *sandbox* ]]; then
  compinit -u
else
  compinit
fi

# Python agent environment
# Note that pip packages should be installed separately on each account.
if [ -f "$HOME/.venvs/default/bin/activate" ]; then
  source "$HOME/.venvs/default/bin/activate"
fi
