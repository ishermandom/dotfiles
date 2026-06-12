#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Offline tests for gh-protect.sh: exercises every code path against a
# stubbed `gh` placed first on PATH, asserting on exit codes and messages.
# Makes no network calls, so it is safe to run anywhere. Requires jq, which
# the stub and gh-protect.sh both use.

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
# Stubbed gh: emulates the read-only gh calls gh-protect.sh makes, driven by
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
    # Emulate `gh api [--method M] ENDPOINT [--jq EXPR]`: pick the canned
    # JSON for ENDPOINT, then apply EXPR with real jq if --jq was passed —
    # the same jq gh-protect.sh would run against the live response.
    jq_expr=""
    endpoint=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --jq) jq_expr="$2"; shift 2 ;;
        --method) shift 2 ;;
        *) endpoint="$1"; shift ;;
      esac
    done
    case "$endpoint" in
      *"rulesets?"*)
        # Ruleset listing.
        response="${GH_STUB_LIST:-[]}"
        ;;
      *rulesets/*)
        # Single-ruleset detail, from a per-id var like GH_STUB_DETAIL_1.
        ruleset_id="${endpoint##*/}"
        detail_var="GH_STUB_DETAIL_$ruleset_id"
        response="${!detail_var}"
        [ -n "$response" ] || response='{}'
        ;;
      *) response='{}' ;;
    esac
    if [ -n "$jq_expr" ]; then
      echo "$response" | jq -r "$jq_expr"
    else
      echo "$response"
    fi
    ;;
esac
exit 0
STUB
chmod +x "$test_root/bin/gh"
PATH="$test_root/bin:$PATH"

# --- fixtures -------------------------------------------------------------

# A ruleset detail response: an include pattern and a list of rule types.
detail() { # detail <include-pattern> <rule-type>...
  local include="$1"
  shift
  local rules=""
  local rule_type
  for rule_type in "$@"; do
    rules="$rules{\"type\": \"$rule_type\"},"
  done
  rules="${rules%,}" # strip the trailing comma
  printf '{"conditions": {"ref_name": {"include": ["%s"]}}, "rules": [%s]}' \
    "$include" "$rules"
}

# A one-entry ruleset listing.
list_one() { # list_one <id> <enforcement>
  printf '[{"id": %s, "target": "branch", "enforcement": "%s"}]' "$1" "$2"
}

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

# Announces the case and resets the stub's call log and knobs.
begin_case() { # begin_case <name>
  echo "case: $1"
  export GH_STUB_LOG="$test_root/$1.log"
  : > "$GH_STUB_LOG"
  unset GH_STUB_LIST GH_STUB_DETAIL_1 GH_STUB_DETAIL_2
  unset GH_STUB_VISIBILITY GH_STUB_FAIL_REPO_VIEW
}

# Runs gh-protect.sh, capturing combined stdout+stderr into `output` and
# the exit status into `exit_code` for the assertions that follow.
run_script() {
  # 2>&1: warnings and errors go to stderr; assertions check both streams.
  output=$("$gh_protect" "$@" 2>&1)
  exit_code=$?
}

calls() { cat "$GH_STUB_LOG"; }

# --- cases ----------------------------------------------------------------

# A single ruleset, arbitrarily named, covers everything — name is ignored.
begin_case protected-single-ruleset
export GH_STUB_LIST=$(list_one 1 active)
export GH_STUB_DETAIL_1=$(detail "~ALL" \
  deletion non_fast_forward required_linear_history)
run_script
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "reports protection" contains "$output" "is protected"
expect "sends no write request" not_contains "$(calls)" "--method"

# Protection split across two rulesets still counts — structure is ignored.
begin_case protected-split-across-rulesets
export GH_STUB_LIST='[{"id": 1, "target": "branch", "enforcement": "active"},
  {"id": 2, "target": "branch", "enforcement": "active"}]'
export GH_STUB_DETAIL_1=$(detail "~ALL" deletion non_fast_forward)
export GH_STUB_DETAIL_2=$(detail "~ALL" required_linear_history)
run_script
expect "exits 0" [ "$exit_code" -eq 0 ]
expect "reports protection" contains "$output" "is protected"

# One protection missing: the message names just that one.
begin_case missing-one-protection
export GH_STUB_LIST=$(list_one 1 active)
export GH_STUB_DETAIL_1=$(detail "~ALL" deletion non_fast_forward)
run_script
expect "exits 3" [ "$exit_code" -eq 3 ]
expect "reports the gap" contains "$output" "is not fully protected"
expect "names the missing protection" \
  contains "$output" "require linear history"
expect "omits the satisfied ones" \
  not_contains "$output" "no active all-branch ruleset enforces: block"
expect "prints a config to create" contains "$output" '"~ALL"'

# A ruleset that targets only the default branch does not protect all
# branches, so nothing is covered.
begin_case ruleset-not-all-branches
export GH_STUB_LIST=$(list_one 1 active)
export GH_STUB_DETAIL_1=$(detail "~DEFAULT_BRANCH" \
  deletion non_fast_forward required_linear_history)
run_script
expect "exits 3" [ "$exit_code" -eq 3 ]
expect "names every protection missing" \
  contains "$output" "block force pushes"
expect "names linear history missing" \
  contains "$output" "require linear history"

# A disabled ruleset enforces nothing, even with the right rules.
begin_case ruleset-disabled
export GH_STUB_LIST=$(list_one 1 disabled)
export GH_STUB_DETAIL_1=$(detail "~ALL" \
  deletion non_fast_forward required_linear_history)
run_script
expect "exits 3" [ "$exit_code" -eq 3 ]
expect "reports the gap" contains "$output" "is not fully protected"

begin_case no-rulesets
run_script
expect "exits 3" [ "$exit_code" -eq 3 ]
expect "reports the gap" contains "$output" "is not fully protected"
expect "prints a config to create" \
  contains "$output" '"required_linear_history"'
expect "sends no write request" not_contains "$(calls)" "--method"

begin_case private-repo-warning
export GH_STUB_VISIBILITY=PRIVATE
export GH_STUB_LIST=$(list_one 1 active)
export GH_STUB_DETAIL_1=$(detail "~ALL" \
  deletion non_fast_forward required_linear_history)
run_script
expect "warns about Free-plan enforcement" \
  contains "$output" "does not enforce rulesets on private repos"

begin_case explicit-repo-argument
run_script someowner/somerepo
expect "passes the argument to gh repo view" \
  contains "$(calls)" "repo view someowner/somerepo"

begin_case rejects-write-flag
run_script --apply
expect "exits 2" [ "$exit_code" -eq 2 ]
expect "prints usage" contains "$output" "usage:"
expect "makes no gh call" [ -z "$(calls)" ]

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
