#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Offline tests for gh-protect.sh: exercises every code path against a
# stubbed `gh` placed first on PATH, asserting on exit codes, messages, and
# the JSON request bodies the script would send. Makes no network calls, so
# it is safe to run anywhere. Requires python3 (for JSON validation only).

script_dir=$(cd "$(dirname "$0")" && pwd)
gh_protect="$script_dir/gh-protect.sh"

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# --- gh stub ----------------------------------------------------------------

mkdir "$test_root/bin"
# Quoted delimiter: the $GH_STUB_* references must survive into the stub and
# resolve when it runs, not when this file is written.
cat > "$test_root/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Stubbed gh: emulates the three calls gh-protect.sh makes, driven by
# GH_STUB_* environment variables, and logs every invocation to
# $GH_STUB_LOG for the test assertions.
echo "CALL: $*" >> "$GH_STUB_LOG"
case "$1" in
  repo)
    if [ -n "${GH_STUB_FAIL_REPO_VIEW:-}" ]; then
      echo "GraphQL: Could not resolve to a Repository" >&2
      exit 1
    fi
    # gh-protect.sh asks for nameWithOwner and visibility joined by a space.
    echo "ishermandom/testrepo ${GH_STUB_VISIBILITY:-PUBLIC}"
    ;;
  api)
    shift
    method="GET"
    if [ "$1" = "--method" ]; then
      method="$2"
      shift 2
    fi
    case "$method" in
      GET)
        case "$1" in
          *"rulesets?"*)
            # Ruleset listing: emit the pre-existing ruleset id, if any.
            if [ -n "${GH_STUB_EXISTING_ID:-}" ]; then
              echo "$GH_STUB_EXISTING_ID"
            fi
            ;;
          *rulesets/*)
            # Single-ruleset fetch: emit the projection gh-protect.sh
            # requests via --jq — the expected config, except where a
            # GH_STUB_LIVE_* knob overrides a field.
            cat <<DETAIL
{
  "name": "gh-protect",
  "target": "branch",
  "enforcement": "${GH_STUB_LIVE_ENFORCEMENT:-active}",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["~ALL"], "exclude": []}},
  "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}]
}
DETAIL
            ;;
        esac
        ;;
      POST | PUT)
        # Capture the JSON request body the script sent via --input -.
        cat > "$GH_STUB_LOG.body"
        echo "{}"
        ;;
    esac
    ;;
esac
exit 0
STUB
chmod +x "$test_root/bin/gh"
PATH="$test_root/bin:$PATH"

# --- assertion helpers --------------------------------------------------

failure_count=0

# Runs the given command as an assertion: prints one result line, and on
# failure bumps failure_count so the script exits non-zero at the end.
expect() { # expect <description> <command...>
  local description="$1"
  shift
  if "$@"; then
    echo "  ok: $description"
  else
    echo "  FAIL: $description" >&2
    failure_count=$((failure_count + 1))
  fi
}

contains() { # contains <haystack> <needle>
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

not_contains() { # not_contains <haystack> <needle>
  ! contains "$1" "$2"
}

is_valid_json() { # is_valid_json <file>
  # 2>/dev/null: suppress the parse-error traceback; the assertion's
  # pass/fail line is the report.
  python3 -c 'import json, sys; json.load(sys.stdin)' < "$1" 2> /dev/null
}

# Announces the case and resets the stub's call log and knobs.
begin_case() { # begin_case <name>
  echo "case: $1"
  export GH_STUB_LOG="$test_root/$1.log"
  : > "$GH_STUB_LOG"
  rm -f "$GH_STUB_LOG.body"
  unset GH_STUB_EXISTING_ID GH_STUB_VISIBILITY GH_STUB_FAIL_REPO_VIEW
  unset GH_STUB_LIVE_ENFORCEMENT
}

# Runs gh-protect.sh, capturing combined stdout+stderr into `output` and
# the exit status into `exit_code` for the assertions that follow.
run_script() {
  # 2>&1: warnings and errors go to stderr; assertions check both streams.
  output=$("$gh_protect" "$@" 2>&1)
  exit_code=$?
}

calls() { cat "$GH_STUB_LOG"; }

request_body() {
  # 2>/dev/null: the body file only exists after a POST or PUT; absence
  # reads as an empty body.
  cat "$GH_STUB_LOG.body" 2> /dev/null
}

# --- cases ----------------------------------------------------------------

begin_case verify-missing
run_script
expect "exits 3" [ "$exit_code" -eq 3 ]
expect "reports the gap" contains "$output" "is not protected"
expect "prints the expected config" contains "$output" '"~ALL"'
expect "suggests --apply" contains "$output" "--apply"
expect "sends no write request" not_contains "$(calls)" "--method"

begin_case verify-matching
export GH_STUB_EXISTING_ID=42
run_script
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "reports protection" \
  contains "$output" "matches the expected config"
expect "sends no write request" not_contains "$(calls)" "--method"

begin_case verify-differing
export GH_STUB_EXISTING_ID=42
export GH_STUB_LIVE_ENFORCEMENT=disabled
run_script
expect "exits 3" [ "$exit_code" -eq 3 ]
expect "reports the drift" \
  contains "$output" "differs from the expected config"
expect "suggests --apply" contains "$output" "--apply"
expect "diffs away the current value" \
  contains "$output" '-  "enforcement": "disabled"'
expect "diffs in the expected value" \
  contains "$output" '+  "enforcement": "active"'
expect "sends no write request" not_contains "$(calls)" "--method"

begin_case apply-create
run_script --apply
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "reports creation" contains "$output" "created ruleset"
expect "POSTs to the rulesets endpoint" contains "$(calls)" \
  "api --method POST repos/ishermandom/testrepo/rulesets --input -"
expect "sends valid JSON" is_valid_json "$GH_STUB_LOG.body"
expect "targets all branches" contains "$(request_body)" '"~ALL"'
expect "sends no bypass actors" \
  contains "$(request_body)" '"bypass_actors": []'
expect "blocks deletion" contains "$(request_body)" '{"type": "deletion"}'
expect "blocks force pushes" \
  contains "$(request_body)" '{"type": "non_fast_forward"}'
expect "enforces actively" \
  contains "$(request_body)" '"enforcement": "active"'

begin_case apply-update
export GH_STUB_EXISTING_ID=42
export GH_STUB_LIVE_ENFORCEMENT=disabled
run_script --apply
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "reports the update" contains "$output" "updated ruleset"
expect "PUTs to the existing ruleset" contains "$(calls)" \
  "api --method PUT repos/ishermandom/testrepo/rulesets/42 --input -"
expect "sends valid JSON" is_valid_json "$GH_STUB_LOG.body"

begin_case apply-noop
export GH_STUB_EXISTING_ID=42
run_script --apply
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "reports protection" \
  contains "$output" "matches the expected config"
expect "sends no write request" not_contains "$(calls)" "--method"

begin_case private-repo-warning
export GH_STUB_VISIBILITY=PRIVATE
run_script
expect "warns about Free-plan enforcement" \
  contains "$output" "does not enforce rulesets on private repos"

begin_case explicit-repo-argument
run_script someowner/somerepo
expect "passes the argument to gh repo view" \
  contains "$(calls)" "repo view someowner/somerepo"

begin_case unknown-flag
run_script --bogus
expect "exits 2" [ "$exit_code" -eq 2 ]
expect "prints usage" contains "$output" "usage:"

begin_case extra-positional-argument
run_script a/b c/d
expect "exits 2" [ "$exit_code" -eq 2 ]
expect "prints usage" contains "$output" "usage:"

begin_case unresolvable-repo
export GH_STUB_FAIL_REPO_VIEW=1
run_script nosuch/repo
expect "exits 1" [ "$exit_code" -eq 1 ]
expect "explains the failure" \
  contains "$output" "cannot resolve target repo"

# --- summary ----------------------------------------------------------------

echo
if [ "$failure_count" -eq 0 ]; then
  echo "gh-protect tests: all passed"
else
  echo "gh-protect tests: $failure_count assertion(s) failed" >&2
  exit 1
fi
