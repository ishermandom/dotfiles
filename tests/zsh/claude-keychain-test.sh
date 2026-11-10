#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for zsh/.claude-keychain.zsh. Each case builds a scratch keychain under
# a temporary HOME and asserts on what the audit reports. Keychains are created
# only inside that scratch tree and never joined to the account's search list,
# so the real Claude keychain is untouched.
#
# The audit ships in the zsh stow package, whose contents install into $HOME, so
# a test beside it would be symlinked into the home directory. Tests for a
# package therefore live under tests/<package>/ instead.

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root="$script_dir/../.."
audit_file="$repo_root/zsh/.claude-keychain.zsh"

source "$repo_root/claude/scripts/shell-test-framework.sh"

require_commands security zsh openssl

# --- id stub ----------------------------------------------------------------

# Quoted delimiter: $ID_STUB_ACCOUNT must resolve when the stub runs, not when
# this file is written.
stub_executable "$test_script_root/bin/id" << 'STUB'
# Stubbed id: reports whichever account a case is exercising, so the audit's
# main-account guard can be driven from either side on any machine.
echo "$ID_STUB_ACCOUNT"
STUB

# --- helpers ----------------------------------------------------------------

# Creates the current case's keychain at the path the audit reads, and echoes
# that path so the case can add entries to it.
make_keychain() { # make_keychain
  local keychain="$case_dir/Library/Keychains/claude-code.keychain-db"
  mkdir -p "$case_dir/Library/Keychains"
  # The empty password matches the real keychain, which the audit unlocks with.
  security create-keychain -p "" "$keychain" > /dev/null
  echo "$keychain"
}

# Sources the audit against the current case's HOME and prints everything it
# reported. The stubbed `id` goes first on PATH so the account name is the
# case's to choose; it defaults to a sandbox account, the side that audits.
run_audit() { # run_audit [account]
  HOME="$case_dir" ID_STUB_ACCOUNT="${1:-claude-sandbox}" \
    PATH="$test_script_root/bin:$PATH" \
    zsh -c "source '$audit_file'" 2>&1
}

# --- cases ------------------------------------------------------------------

begin_case missing_credential
make_keychain > /dev/null
output=$(run_audit)
expect "reports the credential missing" \
  contains "$output" "is missing Claude Code-credentials"
expect "names /login as the fix" contains "$output" "/login"

begin_case credential_present
keychain=$(make_keychain)
security add-generic-password -s "Claude Code-credentials" -a tester -w secret \
  "$keychain"
output=$(run_audit)
expect_equal "stays silent" "$output" ""

begin_case unexpected_service
keychain=$(make_keychain)
security add-generic-password -s "Claude Code-credentials" -a tester -w secret \
  "$keychain"
security add-generic-password -s "Chrome Safe Storage" -a Chrome -w secret \
  "$keychain"
output=$(run_audit)
expect "names the unexpected service" contains "$output" "Chrome Safe Storage"
expect "does not report the credential missing" \
  not_contains "$output" "is missing"
# The report lists only what does not belong, so Claude's own entry is absent
# from it even though the keychain holds one.
expect "leaves Claude's own credential out of the report" \
  not_contains "$output" "Claude Code-credentials"

begin_case unexpected_internet_password
keychain=$(make_keychain)
security add-generic-password -s "Claude Code-credentials" -a tester -w secret \
  "$keychain"
security add-internet-password -s example.com -a tester -w secret "$keychain"
output=$(run_audit)
expect "names the internet password's server" contains "$output" "example.com"

begin_case unexpected_certificate
keychain=$(make_keychain)
security add-generic-password -s "Claude Code-credentials" -a tester -w secret \
  "$keychain"
# Any certificate will do. Apple's root, copied from the system's own roots,
# needs no generating.
security find-certificate -c "Apple Root CA" -p \
  /System/Library/Keychains/SystemRootCertificates.keychain \
  > "$case_dir/certificate.pem"
security import "$case_dir/certificate.pem" -k "$keychain" > /dev/null
output=$(run_audit)
expect "names the certificate" contains "$output" "certificate: Apple Root CA"

begin_case unexpected_private_key
keychain=$(make_keychain)
security add-generic-password -s "Claude Code-credentials" -a tester -w secret \
  "$keychain"
openssl genrsa -out "$case_dir/key.pem" 2048 2> /dev/null
security import "$case_dir/key.pem" -k "$keychain" > /dev/null
output=$(run_audit)
expect "reports the private key" contains "$output" "private key:"

begin_case both_faults_reported_together
keychain=$(make_keychain)
security add-generic-password -s "Chrome Safe Storage" -a Chrome -w secret \
  "$keychain"
output=$(run_audit)
expect "reports the credential missing" \
  contains "$output" "is missing Claude Code-credentials"
expect "also names the unexpected service" \
  contains "$output" "Chrome Safe Storage"

begin_case absent_keychain
# No keychain built for this case: the audit should refuse rather than report a
# clean bill of health for a keychain that is not there.
output=$(run_audit)
status=$?
expect "reports the keychain absent" contains "$output" "keychain not found"
expect "returns non-zero" test "$status" -ne 0

begin_case main_account_skips_audit
keychain=$(make_keychain)
security add-generic-password -s "Chrome Safe Storage" -a Chrome -w secret \
  "$keychain"
output=$(run_audit ishermandom)
expect_equal "leaves the GUI account's keychain unaudited" "$output" ""

exit_with_summary
