#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Token-lean rustfmt runner: formats every Rust crate under the current
# directory, printing nothing unless rustfmt has something to say. Canonical
# rustfmt invocation — the Stop hook's formatter step delegates here.
#
# Each crate is formatted through `cargo fmt` rather than bare `rustfmt`, since
# rustfmt handed a file on its own ignores the edition the crate's Cargo.toml
# declares and formats by the 2015 edition's rules instead.
#
# Exits 0 when every crate came out formatted, or when there is none, and 2 when
# rustfmt could not format one — a file it cannot parse, most often. rustfmt
# fixes whatever it can parse, so it has no findings level in between; see the
# exit-status scales in claude/hooks/format.sh.
#
# Usage: quiet-rustfmt.sh

# $# counts the arguments; the runner takes none.
if [ $# -gt 0 ]; then
  echo "usage: quiet-rustfmt.sh" >&2
  exit 2
fi

# This script's directory in its own checkout: `readlink -f` follows the
# `~/.claude` symlink.
scripts_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "$scripts_dir/homebrew-path.sh"
source "$scripts_dir/file-listing.sh"

# `${#crate_manifests[@]}` counts the crates found; with none, there is nothing
# to format.
find_crate_manifests
[ ${#crate_manifests[@]} -gt 0 ] || exit 0

if ! command -v cargo > /dev/null; then
  echo "rustfmt: cargo not found; install it with 'brew install rust'"
  exit 127
fi

status=0
for manifest in "${crate_manifests[@]}"; do
  cargo fmt --manifest-path "$manifest" 2>&1 || status=2
done
exit $status
