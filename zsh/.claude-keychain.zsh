# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Unlock Claude Code's dedicated login keychain and audit its contents.
#
# Claude Code persists its OAuth login to the macOS keychain, writing to the
# default keychain. This account is reached over ssh, where its login keychain
# stays locked, so Claude has nowhere it can write — without the dedicated
# keychain below, every session re-prompts for /login and Remote Control fails.
# Unlock it at login, and warn if Claude's credential goes missing or any other
# entry appears.
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

# Prints one line per entry in the keychain at $1, as `<kind>: <name>`.
# dump-keychain prints attributes only, never secret values, so its output is
# safe to surface. It opens each entry's block with a `keychain:` line, so awk
# gathers one block's class and naming attributes, then prints them as the next
# block begins.
claude_keychain_entries() { # claude_keychain_entries <keychain>
  security dump-keychain "$1" | awk '
    function kind_of(class) {
      if (class == "\"genp\"") return "password"
      if (class == "\"inet\"") return "internet password"
      if (class == "0x80001000") return "certificate"
      if (class == "0x0000000F") return "public key"
      if (class == "0x00000010") return "private key"
      if (class == "0x00000011") return "symmetric key"
      return "class " class
    }
    # The quoted text after `="`, without its closing quote.
    function value(  start) {
      start = index($0, "=\"") + 2
      return substr($0, start, length($0) - start)
    }
    # A password is named by its service, an internet password by its
    # server, and a certificate or key by its label, which a key prints
    # under the numeric attribute 0x00000001.
    function flush(  name) {
      name = service != "" ? service : server != "" ? server : label
      if (kind != "") print kind ": " name
      kind = service = server = label = ""
    }
    /^keychain: / { flush() }
    /^class: / { kind = kind_of($2) }
    /"svce"<blob>="/ { service = value() }
    /"srvr"<blob>="/ { server = value() }
    /("labl"|0x00000001 )<blob>="/ { if (label == "") label = value() }
    END { flush() }
  '
}

claude_keychain_init() {
  local keychain_path="$HOME/Library/Keychains/claude-code.keychain-db"
  local required_service="Claude Code-credentials"
  local required_entry="password: $required_service"
  # `-a` declares these as arrays, holding one element per keychain entry.
  local -a entries claude_entries unexpected_entries

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

  # The `f` flag splits the listing into one array element per entry. Keep the
  # command substitution quoted: unquoted, the lines arrive pre-joined and `f`
  # finds nothing to split.
  entries=(${(f)"$(claude_keychain_entries "$keychain_path")"})

  # `${array:#pattern}` drops the elements matching the pattern, and the `M`
  # flag keeps them instead, so these two are complements — one split of the
  # entry list answers both of the questions below.
  claude_entries=(${(M)entries:#$required_entry})
  unexpected_entries=(${entries:#$required_entry})

  # A missing credential means the login did not persist — surface that here
  # rather than leave the next session to meet a surprise /login prompt.
  if ((${#claude_entries} == 0)); then
    echo "WARNING: $keychain_path is missing $required_service" >&2
    echo "  Claude's login did not persist; run 'claude' + /login." >&2
  fi

  # Any other entry is protected by nothing but this account's file permissions.
  # This keychain is the account's default, so it catches whatever an app
  # stores without naming a keychain, of every kind — a certificate or key as
  # readily as a password. Logging the account into a desktop session is one such
  # source, since macOS's own services then store entries here too. Fix an
  # arrival at its source rather than adding it to an allowlist here.
  if ((${#unexpected_entries} > 0)); then
    echo "WARNING: $keychain_path holds unexpected entries" >&2
    echo "  this keychain unlocks with an empty password," \
      "so it is the wrong home for:" >&2
    # printf reuses its format for each argument, giving one line per entry.
    printf '    - %s\n' "${unexpected_entries[@]}" >&2
  fi
}

# The main GUI account (ishermandom) uses the standard login keychain; every
# other account is defensively assumed to be a headless Claude sandbox that
# needs this unlock + audit. id -un (not $USER) is the authoritative,
# unspoofable account name.
[[ "$(id -un)" != ishermandom ]] && claude_keychain_init
