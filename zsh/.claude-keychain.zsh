# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Unlock Claude Code's dedicated login keychain and audit its contents.
#
# Claude Code persists its OAuth login to the macOS keychain. This account is
# headless (reached via `su`, no GUI login), so it has no login keychain for
# Claude to write to — without the dedicated keychain below, every session
# re-prompts for /login and Remote Control fails. Unlock it at login and warn
# if it ever holds anything other than Claude's single credential.
#
# Note: one-time setup on a new machine — create the keychain with an empty
# password, keep it unlocked, and make it the default write target:
#   security create-keychain -p "" ~/Library/Keychains/claude-code.keychain-db
#   security set-keychain-settings ~/Library/Keychains/claude-code.keychain-db
#   security list-keychains -d user -s \
#     ~/Library/Keychains/claude-code.keychain-db \
#     /Library/Keychains/System.keychain
#   security default-keychain -d user -s \
#     ~/Library/Keychains/claude-code.keychain-db
# Then run `claude` once and `/login` to populate it. The empty password is
# deliberate: an unattended unlock after reboot can hold no stored secret, so
# protection rests on this account's filesystem permissions — the same model as
# a chmod 600 credentials file.

claude_keychain_init() {
  local keychain_path="$HOME/Library/Keychains/claude-code.keychain-db"
  local expected_service="Claude Code-credentials"
  local services entry_count unexpected_services

  if [[ ! -f "$keychain_path" ]]; then
    echo "ERROR: Claude Code keychain not found at $keychain_path" >&2
    echo "  Run the one-time setup in the Note above, then 'claude' + /login." >&2
    return 1
  fi

  # Empty-password unlock (idempotent if already unlocked). A failure means the
  # keychain's password is no longer empty; surface it rather than let Claude
  # silently fall back to a /login prompt — the audit below cannot catch this,
  # since dump-keychain reads attributes even while the keychain stays locked.
  if ! security unlock-keychain -p "" "$keychain_path"; then
    echo "WARNING: could not unlock $keychain_path with the empty password" >&2
  fi

  # dump-keychain prints attributes only, never secret values, so its output is
  # safe to surface. Each generic-password item carries one "svce" service line.
  services=$(security dump-keychain "$keychain_path" \
    | grep '"svce"<blob>=' \
    | sed 's/.*<blob>="\(.*\)"/\1/')
  # grep -c . counts non-empty lines (entries); grep -vx lists any whose service
  # is not exactly Claude's — i.e. credentials that should not be here.
  entry_count=$(printf '%s' "$services" | grep -c .)
  unexpected_services=$(printf '%s\n' "$services" | grep -vx "$expected_service")

  if [[ "$entry_count" -ne 1 || -n "$unexpected_services" ]]; then
    echo "WARNING: $keychain_path holds unexpected entries" >&2
    echo "  expected exactly one ($expected_service); found $entry_count:" >&2
    printf '%s\n' "$services" | sed 's/^/    - /' >&2
  fi
}

claude_keychain_init
