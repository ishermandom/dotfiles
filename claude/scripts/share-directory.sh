#!/bin/bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

# Grant both machine accounts (ishermandom + claude-sandbox) full access to a
# directory tree, using inheritable macOS ACLs — the sharing mechanism behind
# /Users/Shared/code and /Users/Shared/models.
#
# Why ACLs instead of POSIX bits: inherited ACL entries apply to everything
# later created inside the tree regardless of the creating process's umask or
# permission bits, so tools that write owner-only files (e.g. Hugging Face
# downloads, which arrive as 0600) still come out readable and writable by
# both accounts. POSIX modes are left untouched: world visibility stays
# whatever the tree already had.
#
# Inheritance only fires when a file is created inside a covered directory.
# A tree MOVED into a covered directory keeps its old ACLs — that is the
# main occasion for this script: run it on the moved tree. Re-running is
# harmless; chmod +a deduplicates identical entries.
#
# Usage: share-directory.sh <directory>
# Must be run by the tree's owner (or root): adding ACL entries requires
# ownership of each file, so a mixed-ownership tree needs sudo.

shared_accounts=(ishermandom claude-sandbox)

# Everything short of ownership transfer: read/write/delete for files,
# list/add/delete-children for directories, attribute and extended-attribute
# access, plus the two inherit flags that propagate this entry to new
# children. chmod translates the directory-specific names (list, add_file,
# ...) to their file equivalents (read, write, ...) on plain files and drops
# the inherit flags there.
# += appends to the string, splitting one long list across readable lines.
permissions='list,add_file,search,delete,add_subdirectory,delete_child'
permissions+=',readattr,writeattr,readextattr,writeextattr,readsecurity'
permissions+=',file_inherit,directory_inherit'

# $# is the argument count: exactly one argument, and it must be a directory.
if [ $# -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $(basename "$0") <directory>" >&2
  echo "  $1: not a directory" >&2
  exit 1
fi
target_directory=$1

for account in "${shared_accounts[@]}"; do
  if ! chmod -R +a "user:${account} allow ${permissions}" \
      "$target_directory"; then
    echo "failed to apply ${account} ACL to ${target_directory}" >&2
    echo "(not the owner of some files? try with sudo)" >&2
    exit 1
  fi
done

# Show the resulting entries on the root so success is verifiable at a glance.
ls -led "$target_directory"
