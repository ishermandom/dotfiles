# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Unlock Claude Code's dedicated login keychain and audit its contents.
#
# Claude Code persists its OAuth login to the macOS keychain. This account is
# headless (reached via `su`, no GUI login), so it has no login keychain for
# Claude to write to — without the dedicated keychain below, every session
# re-prompts for /login and Remote Control fails. Unlock it at login, and warn
# if Claude's credential goes missing or an unexpected one appears.
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
  local required_service="Claude Code-credentials"
  # `-a` declares these as arrays, holding one element per keychain service.
  local -a services claude_entries unexpected_services

  if [[ ! -f "$keychain_path" ]]; then
    echo "ERROR: Claude Code keychain not found at $keychain_path" >&2
    echo "  Run the one-time setup in the Note above," \
      "then 'claude' + /login." >&2
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
  # safe to surface. Each generic-password item carries one "svce" service line,
  # and the `f` flag splits those lines into one array element per service. Keep
  # the command substitution quoted: unquoted, the lines arrive pre-joined and
  # `f` finds nothing to split.
  services=(${(f)"$(security dump-keychain "$keychain_path" \
    | grep '"svce"<blob>=' \
    | sed 's/.*<blob>="\(.*\)"/\1/')"})

  # `${array:#pattern}` drops the elements matching the pattern, and the `M`
  # flag keeps them instead, so these two are complements — one split of the
  # service list answers both of the questions below.
  claude_entries=(${(M)services:#$required_service})
  unexpected_services=(${services:#$required_service})

  # A missing credential means the login did not persist — surface that here
  # rather than leave the next session to meet a surprise /login prompt.
  if ((${#claude_entries} == 0)); then
    echo "WARNING: $keychain_path is missing $required_service" >&2
    echo "  Claude's login did not persist; run 'claude' + /login." >&2
  fi

  # Any other entry is a secret protected by nothing but this account's file
  # permissions. This keychain is the account's default, so it catches whatever
  # an app stores without naming a keychain — fix such an arrival at its source
  # rather than adding it to an allowlist here.
  if ((${#unexpected_services} > 0)); then
    echo "WARNING: $keychain_path holds unexpected credentials" >&2
    echo "  this keychain unlocks with an empty password," \
      "so it is the wrong home for:" >&2
    # printf reuses its format for each argument, giving one line per service.
    printf '    - %s\n' "${unexpected_services[@]}" >&2
  fi
}

# The main GUI account (ishermandom) uses the standard login keychain; every
# other account is defensively assumed to be a headless Claude sandbox that
# needs this unlock + audit. id -un (not $USER) is the authoritative,
# unspoofable account name.
[[ "$(id -un)" != ishermandom ]] && claude_keychain_init
