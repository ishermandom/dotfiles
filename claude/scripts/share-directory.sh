#!/bin/bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT

# Grant both machine accounts (ishermandom + claude-sandbox) full access to a
# directory tree, using inheritable macOS ACLs — the sharing mechanism behind
# the trees both accounts share under /Users/Shared, such as code/ and cache/.
#
# Why ACLs instead of POSIX bits: inherited ACL entries apply to everything
# later created inside the tree regardless of the creating process's umask or
# permission bits, so tools that write owner-only files (e.g. Hugging Face
# downloads, which arrive as 0600) still come out readable and writable by both
# accounts. POSIX modes are left untouched: world visibility stays whatever the
# tree already had.
#
# For items created after a directory is shared, inheritance does all the work.
# Once a directory carries an inheritable entry, the kernel copies that entry
# onto every item later created inside that directory. The entry's
# `directory_inherit` flag makes each new subdirectory's copy inheritable too,
# so the grant reaches every depth of the tree at no cost.
#
# Inheritance never reaches items that already exist: the kernel applies it only
# as each item is created. Two cases leave items without the grant:
#
# - **Contents at first sharing**: whatever the directory held before the script
#   first added its entry. To cover those contents, the script walks the tree
#   whenever it adds an entry to the root — the directory named on the command
#   line. Re-running on an already-shared root reads the root's ACL and stops,
#   however large the tree.
# - **A tree moved in later** {#moved-in-tree}: a rename creates nothing, so the
#   moved tree keeps its old ACLs. Running the script on the parent finds the
#   parent already shared and walks nothing. Run the script on the moved tree
#   instead: that tree's root lacks the entry, so the script adds one and walks.
#
# Usage: share-directory.sh <directory>
#
# Adding an ACL entry to an item requires owning that item, so walking a
# mixed-ownership tree needs sudo. Re-running on an already-shared root needs no
# sudo.

shared_accounts=(ishermandom claude-sandbox)

# Everything short of ownership transfer: read/write/delete for files,
# list/add/delete-children for directories, attribute and extended-attribute
# access, plus the two inherit flags that propagate this entry to new children.
# chmod translates the directory-specific names (list, add_file, ...) to their
# file equivalents (read, write, ...) on plain files and drops the inherit flags
# there.
#
# Keep the names in chmod's canonical order, which is the order `ls -e` prints
# them in: `grants_full_access` matches this string against that output. A
# reordered string never matches, so every run would try to share the tree
# afresh, walking it in full.
#
# += appends to the string, splitting one long list across readable lines.
permissions='list,add_file,search,delete,add_subdirectory,delete_child'
permissions+=',readattr,writeattr,readextattr,writeextattr,readsecurity'
permissions+=',file_inherit,directory_inherit'

script_name="$(basename "$0")"

# $# is the argument count: exactly one argument, and it must be a directory.
if [ $# -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $script_name <directory>" >&2
  # With exactly one argument, the failure is that it isn't a directory.
  if [ $# -eq 1 ]; then
    echo "  $1: not a directory" >&2
  fi
  exit 1
fi
target_directory=$1

# Whether the target directory's ACL already holds the `permissions` entry for
# the given account.
#
# An entry the directory inherited from its own parent counts, since that entry
# grants identical access. Re-adding it anyway would not be a no-op: `chmod +a`
# treats an inherited entry as distinct from the one being added, so the command
# appends a duplicate.
grants_full_access() {
  local account="$1"
  local inherited_marker='(inherited )?'
  local entry_pattern="user:${account} ${inherited_marker}allow ${permissions}"
  # `ls -e` is the only way to read an ACL; `-d` lists the directory itself
  # rather than its contents.
  local acl_listing
  acl_listing="$(ls -led "$target_directory")"
  # `<<<` feeds the listing to grep as input; grep's exit status becomes the
  # function's result.
  grep -Eq "$entry_pattern" <<< "$acl_listing"
}

# Extend the grant to items that predate it, for one account.
#
# `find -exec ... +` batches many paths into each chmod. Symbolic links are
# skipped because chmod acts on a link's target rather than the link itself: a
# dangling link fails, and a live one can lead outside the tree. Skipping them
# loses nothing, since a link's own ACL never governs access to its target.
#
# Failures are ordinary here: chmod needs ownership, and a walked tree can hold
# items another account owns. Collect the failures and summarize them rather
# than printing a line per item.
grant_existing_items() {
  local account="$1"
  local acl_entry="user:${account} allow ${permissions}"
  # Redirections apply left to right: `2>&1` first points stderr at what
  # `$(...)` captures, then `> /dev/null` sends stdout away. In the other order,
  # both streams would go to /dev/null.
  local chmod_errors
  chmod_errors="$(find "$target_directory" \! -type l \
    -exec chmod +a "$acl_entry" {} + 2>&1 > /dev/null)"
  if [ -z "$chmod_errors" ]; then
    return 0
  fi

  # wc pads its count on macOS; tr strips the padding.
  local failure_count
  failure_count="$(printf '%s\n' "$chmod_errors" | wc -l | tr -d ' ')"
  local example_count=3
  echo "$script_name: cannot grant $account access to" \
    "$failure_count item(s):" >&2
  printf '%s\n' "$chmod_errors" | head -"$example_count" | sed 's/^/  /' >&2
  local remaining_count=$((failure_count - example_count))
  if [ "$remaining_count" -gt 0 ]; then
    echo "  ... and $remaining_count more" >&2
  fi
  echo "  (not the owner of some items? try with sudo)" >&2
  return 1
}

# Accounts whose entry this run adds to the root. Only these need the walk: an
# entry already on the root has been copied onto every item created inside since
# that entry was added.
accounts_added=()
exit_status=0

for account in "${shared_accounts[@]}"; do
  if grants_full_access "$account"; then
    continue
  fi
  acl_entry="user:${account} allow ${permissions}"
  if chmod +a "$acl_entry" "$target_directory"; then
    accounts_added+=("$account") # += appends to the array
  else
    echo "$script_name: cannot grant $account access to $target_directory" >&2
    echo "  (not the owner? try with sudo)" >&2
    exit_status=1
  fi
done

# ${#accounts_added[@]} is the array's length.
if [ ${#accounts_added[@]} -eq 0 ]; then
  # The root did not change, so every item created inside it inherited the
  # grant. Only a tree moved in could lack the grant; see #moved-in-tree.
  echo "$script_name: $target_directory already shared; contents skipped"
  echo "  (moved a tree in? run on that tree itself)"
else
  for account in "${accounts_added[@]}"; do
    grant_existing_items "$account" || exit_status=1
  done
fi

# Show the resulting entries on the root so success is verifiable at a glance.
ls -led "$target_directory"

exit "$exit_status"
