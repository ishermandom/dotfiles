#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# A `stop_checks.sh` step: format the current directory, and the dotfiles repo
# when the session is working outside it.
#
# Runs on Stop (end of turn) rather than on each Edit so that all edits from the
# turn have landed before formatting runs. The Stop hook receives no information
# about which files changed, so we format whole directories.
#
# Two things here are easy to conflate:
#
# - the tool — the formatter itself, such as ruff or prettier
# - its runner — a `quiet-<tool>.sh` in ~/.claude/scripts, the canonical
#   invocation of one tool, holding the flags that tool is always run with
#
# A runner and this step report an exit status on different scales, and
# translating one into the other is most of the work here:
#
# - a runner passes its tool's status through on three levels: 0 when the files
#   came out clean, 1 when the tool reported findings it could not fix, and 2 or
#   more when it could not do the job at all — a file it cannot parse, a misuse,
#   or the shell's 127 for a tool that is not installed. Not every tool reaches
#   1 — prettier's --write fixes whatever it can parse, so it reports success or
#   breakage and nothing between.
# - this step reports two levels: 0 when the tools ran, whether or not they
#   found anything, and non-zero when one of them could not run. The reason for
#   a non-zero exit goes to stderr, while whatever the tools said about the
#   files goes to stdout, so a caller can surface one without the other.
#
# So a runner exit of 0 or 1 becomes a step exit of 0, and a runner exit of 2 or
# more fails the step. That split is the point — a missing or broken tool
# otherwise looks exactly like a clean run, and formatting silently fails.

runners_dir="$HOME/.claude/scripts"
runners=(quiet-prettier.sh quiet-ruff.sh)

# Runs every runner over one directory and returns this step's verdict for it.
#
# Both tools skip whatever .gitignore excludes, so formatting a repo does not
# reach the worktrees under `.claude/worktrees/`.
format_dir() { # format_dir <directory>
  # Each runner resolves its own config and file globs against the working
  # directory, so move there rather than passing the path. The subshell scopes
  # the cd, leaving this script's own directory alone.
  (
    cd "$1" || exit 2

    local runner output runner_status
    for runner in "${runners[@]}"; do
      output=$("$runners_dir/$runner" 2>&1)
      runner_status=$?

      # A runner exit of 2 or more is breakage; 0 and 1 alike mean it ran.
      if [ "$runner_status" -gt 1 ]; then
        printf '%s\n' "$output" >&2
        exit "$runner_status"
      fi

      printf '%s\n' "$output"
    done
  )
}

# A broken tool would tend to fail the same way on the next directory, so short
# circuit on failure.
format_dir . || exit $?

# The repo holding this file is the dotfiles repo, so ask git where it starts.
# -f resolves the ~/.claude symlink. git runs in this file's own directory,
# since the current directory may belong to an entirely different repo.
hooks_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
dotfiles_root=$(cd "$hooks_dir" && git rev-parse --show-toplevel 2> /dev/null)

# Outside a checkout there is no dotfiles repo to make a second pass over.
[ -n "$dotfiles_root" ] || exit 0

# A session at or below the root already covers the repo by formatting the
# current directory — including a session inside a worktree, which is a checkout
# of its own. Matching the root with a trailing slash keeps a sibling such as
# dotfiles-backup out.
case "$(realpath .)" in
  "$dotfiles_root" | "$dotfiles_root"/*) exit 0 ;;
esac

format_dir "$dotfiles_root"
