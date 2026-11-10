#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Lists the files under the current directory that git does not ignore, and
# finds two kinds of file in that listing: Rust crate manifests and shell files.
#
# Sourced rather than run, so listing the files starts no shell of its own. The
# shebang only names the dialect for `shellcheck` and editors, and the file is
# deliberately not executable.

# Prints the files under the current directory that match the given pathspecs,
# minus any git ignores, each ending in a NUL byte. Outside a repo, git fails
# without listing anything, so the caller can fall back on a listing of its own.
#
# - `--cached`: the tracked files; the index is what git calls its cache
# - `--others`: the untracked files too
# - `--exclude-standard`: minus any untracked file an ignore rule covers, such
#   as one in a build directory or in a worktree under `.claude/worktrees/`. Git
#   reads every ignore source — each folder's `.gitignore`, `.git/info/exclude`,
#   the global excludes file.
# - `-z`: each path ends in a NUL byte rather than a newline, and an unusual
#   name comes unquoted, so any name arrives whole
#
# git still lists a tracked file the working tree has deleted, so a caller
# checks that each listed file exists before handing it on.
list_unignored_files() { # list_unignored_files <pathspec>...
  git ls-files -z --cached --others --exclude-standard -- "$@" 2> /dev/null
}

# Succeeds when <manifest> declares a `[workspace]` table but no `[package]`
# table. Cargo calls such a manifest virtual. It sits at the root of a workspace
# and lists the workspace's crates. It is not a crate itself. For example:
#
# ```toml
# [workspace]
# members = ["app", "tools"]
# ```
#
# Handed a manifest, `cargo fmt` formats the crate that manifest declares. A
# virtual manifest declares none. So when a workspace has two or more members,
# `cargo fmt` fails on its virtual manifest. (With a single member, `cargo fmt`
# formats that member instead.)
is_workspace_only_manifest() { # is_workspace_only_manifest <manifest>
  # `-x` matches whole lines and `-F` takes the text literally, so the brackets
  # need no escaping.
  grep -qxF '[workspace]' "$1" && ! grep -qxF '[package]' "$1"
}

# Sets the array `crate_manifests` to the Cargo.toml of every Rust crate under
# the current directory, each path relative to that directory. A crate's
# Cargo.toml is its manifest, which cargo takes through `--manifest-path`.
find_crate_manifests() {
  crate_manifests=()

  # `:(glob)` lets `**` match any number of directories, none included, so a
  # crate at the current directory counts too. Outside a repo, that crate is the
  # only candidate.
  #
  # `read -d ''` takes one NUL-ended path at a time, and `IFS=` and `-r` keep
  # its spaces and backslashes as they are. `< <(...)` feeds the loop the
  # listing while keeping the loop in this shell; piped into, the loop would run
  # in a subshell, and the array would come back empty.
  local manifest
  while IFS= read -r -d '' manifest; do
    # A deleted manifest is passed over, as is the candidate outside a repo when
    # the current directory holds no crate. So is a workspace-only manifest,
    # which names no crate; the workspace's members are each found through their
    # own manifests.
    if [ -f "$manifest" ] && ! is_workspace_only_manifest "$manifest"; then
      crate_manifests+=("$manifest")
    fi
  done < <(
    list_unignored_files ':(glob)**/Cargo.toml' || printf 'Cargo.toml\0'
  )
}

# Sets the array `shell_files` to the shell files under the current directory
# that git does not ignore, each path relative to that directory. Outside a
# repo, git ignores nothing, so every file under the current directory is
# considered, except those inside `.git`. When shfmt is missing, returns 2 and
# leaves `shell_files` empty.
#
# A file counts as shell when `shfmt -f` takes it for one, by its extension or
# its shebang. shfmt skips every file whose name starts with a dot, so for those
# files the name alone decides: `.zshrc`, `.zprofile`, and any dot-prefixed name
# ending in `.sh`, `.bash` or `.zsh`.
find_shell_files() {
  shell_files=()

  # Without shfmt, the search would find only the dot-prefixed files, and a
  # caller would wrongly conclude that the rest of the repo holds no shell.
  if ! command -v shfmt > /dev/null; then
    echo "find_shell_files: shfmt is not installed;" \
      "try 'brew install shfmt'" >&2
    return 2
  fi

  # The loop reads the listing as `find_crate_manifests` does. `${candidate#./}`
  # drops the `./` that `find` puts in front of each path, so a file is named
  # the same way in a repo and out of one.
  local candidate shfmt_candidates=() dot_prefixed=()
  while IFS= read -r -d '' candidate; do
    candidate=${candidate#./}

    # A deleted file is passed over, and so is a symlink: shfmt refuses to
    # rewrite one and fails the whole run. A link's target inside the repo is
    # listed under its own name.
    if [ ! -f "$candidate" ] || [ -L "$candidate" ]; then
      continue
    fi

    # `${candidate##*/}` is the file's name without its directories.
    case "${candidate##*/}" in
      .zshrc | .zprofile | .*.sh | .*.bash | .*.zsh)
        dot_prefixed+=("$candidate")
        ;;
      .*) ;;
      *) shfmt_candidates+=("$candidate") ;;
    esac
  done < <(
    list_unignored_files || find . -path '*/.git' -prune -o -type f -print0
  )

  # shfmt prints, one per line, the candidates it takes for shell. xargs runs
  # shfmt as many times as the system's limit on arguments requires.
  if [ ${#shfmt_candidates[@]} -gt 0 ]; then
    while IFS= read -r candidate; do
      shell_files+=("$candidate")
    done < <(printf '%s\0' "${shfmt_candidates[@]}" | xargs -0 shfmt -f)
  fi
  shell_files+=("${dot_prefixed[@]}")
}
