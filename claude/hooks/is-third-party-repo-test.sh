#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests which checkouts the classifier calls someone else's, and which it calls
# the user's own.
#
# Both verdicts fail quietly when they are wrong. Calling the user's own repo
# third-party switches its formatting and checks off, ending every turn clean
# while nothing is being checked; calling someone else's repo the user's own
# rewrites that project's files to this machine's conventions.
#
# The fixtures are real checkouts with real remotes, because remote ownership is
# the whole of what the classifier reads — a fake would be a restatement of it.

script_dir=$(cd "$(dirname "$0")" && pwd)
classifier="$script_dir/is-third-party-repo.sh"

. "$script_dir/../scripts/shell-test-framework.sh"

require_commands git

# --- case helpers -----------------------------------------------------------

# Begins a case holding an empty checkout at `$checkout`. Remotes are left to
# each case, so every URL under test stays visible at its call site.
begin_checkout_case() { # begin_checkout_case <name>
  begin_case "$1"
  checkout="$case_dir/checkout"
  mkdir -p "$checkout"
  git -C "$checkout" init --quiet
}

# The classifier's verdict as a word. Comparing words with expect_equal makes a
# failure say which verdict came back, where an exit status alone would not.
verdict_for() { # verdict_for <path>
  if "$classifier" "$1"; then
    echo third-party
  else
    echo own
  fi
}

# --- someone else's checkout ------------------------------------------------

begin_checkout_case a-plain-clone
git -C "$checkout" remote add origin https://github.com/zed-industries/zed.git

expect_equal "a clone of another account's project is third-party" \
  "$(verdict_for "$checkout")" third-party

# The shape the ownership rule exists for: a fork's own `origin` is the user's,
# and only the `upstream` remote gives it away.
begin_checkout_case a-fork
git -C "$checkout" remote add origin \
  git@github.com:ishermandom/google-photos-deduper.git
git -C "$checkout" remote add upstream \
  https://github.com/mtalcott/google-photos-deduper

expect_equal "a fork of another account's project is third-party" \
  "$(verdict_for "$checkout")" third-party

begin_checkout_case a-remote-with-several-urls
git -C "$checkout" remote add upstream \
  https://github.com/mtalcott/google-photos-deduper
git -C "$checkout" remote set-url --add upstream \
  https://github.com/xob0t/Google-Photos-Toolkit.git

expect_equal "every url of a multi-url remote is read" \
  "$(verdict_for "$checkout")" third-party

# A remote whose URL names no account cannot be shown to be the user's, and the
# hooks this guards rewrite files — so the unrecognized shape is the cautious
# verdict rather than the permissive one.
begin_checkout_case a-remote-naming-no-account
git -C "$checkout" remote add origin /srv/mirrors/bare.git

expect_equal "a url with no account in it is third-party" \
  "$(verdict_for "$checkout")" third-party

# --- the user's own checkout ------------------------------------------------

begin_checkout_case an-owned-ssh-remote
git -C "$checkout" remote add origin git@github.com:ishermandom/dotfiles.git

expect_equal "an owned account over ssh is the user's own" \
  "$(verdict_for "$checkout")" own

begin_checkout_case an-owned-https-remote
git -C "$checkout" remote add origin https://github.com/ishermandom/bridge.git

expect_equal "an owned account over https is the user's own" \
  "$(verdict_for "$checkout")" own

# A project that has not been pushed anywhere is still the user's, and switching
# its checks off would be the silent-failure direction of a wrong verdict.
begin_checkout_case no-remotes-at-all
expect_equal "a checkout with no remotes is the user's own" \
  "$(verdict_for "$checkout")" own

begin_case outside-any-checkout
expect_equal "a directory in no repo at all is the user's own" \
  "$(verdict_for "$case_dir")" own

# --- what the classifier accepts as a path ----------------------------------

# Hooks hand over the path of the file just edited, so a file argument has to
# stand for the directory holding it rather than failing git outright.
begin_checkout_case a-file-inside-a-checkout
git -C "$checkout" remote add origin https://github.com/rust-lang/cargo.git
touch "$checkout/README.md"

expect_equal "a file argument is read as its directory" \
  "$(verdict_for "$checkout/README.md")" third-party

# A worktree is a checkout of its own, sharing the remotes of the repo it
# branched from — so a session inside one has to reach the same verdict.
begin_checkout_case a-worktree-of-someone-elses-checkout
git -C "$checkout" remote add origin https://github.com/zed-industries/zed.git
# `git worktree add` needs a commit to branch from. The identity and signing
# settings come from flags so the case does not depend on the user's git config.
git -C "$checkout" -c user.name=test -c user.email=test@example.com \
  -c commit.gpgsign=false commit --quiet --allow-empty -m "fixture"
git -C "$checkout" worktree add --quiet "$case_dir/worktree"

expect_equal "a worktree inherits its repo's verdict" \
  "$(verdict_for "$case_dir/worktree")" third-party

# --- calling it wrong -------------------------------------------------------

# Exit 1 is a verdict, so a caller's mistake must not land on it and read as
# "the user's own".
begin_case no-argument
"$classifier" > "$case_dir/stdout" 2> "$case_dir/stderr"
exit_code=$?

expect "a missing argument exits with neither verdict" test "$exit_code" -eq 2
expect "a missing argument explains itself" \
  contains "$(cat "$case_dir/stderr")" "usage"
expect "a missing argument prints no verdict" test ! -s "$case_dir/stdout"

# --- summary ----------------------------------------------------------------

exit_with_summary
