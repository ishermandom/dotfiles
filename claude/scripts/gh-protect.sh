#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Verifies that a GitHub repo carries the branch-protection backstop — a
# ruleset blocking force pushes and branch deletion on all branches — and
# reports any gap. By default the script only reads; pass --apply to also
# converge the repo: create the missing ruleset, or overwrite a differing
# one. Run it whenever a new repo is created.
#
# Verification needs only read access on the repo. --apply needs the
# Administration: write permission — keeping that off everyday tokens is
# deliberate, since a token that can edit rulesets can also remove them,
# defeating the backstop.
#
# Usage: gh-protect.sh [--apply] [[HOST/]OWNER/REPO]
#
# Defaults to the current directory's repo. Exit codes: 0 = protected (or
# successfully applied); 1 = operational error; 2 = usage error;
# 3 = not protected (ruleset missing or differing).

ruleset_name="gh-protect"

usage() {
  echo "usage: gh-protect.sh [--apply] [[HOST/]OWNER/REPO]" >&2
  exit 2
}

# Reprints JSON with sorted keys and uniform indentation, so equality
# checks and diffs reflect content rather than formatting.
normalize_json() {
  python3 -c 'import json, sys
print(json.dumps(json.load(sys.stdin), indent=2, sort_keys=True))'
}

should_apply=false
repo_argument=""
for argument in "$@"; do
  case "$argument" in
    --apply)
      should_apply=true
      ;;
    -*)
      usage
      ;;
    *)
      # At most one positional argument: the target repo.
      if [ -n "$repo_argument" ]; then
        usage
      fi
      repo_argument="$argument"
      ;;
  esac
done

# Resolve and validate the target repo in one step: with no argument,
# gh infers the repo from the current directory's git remotes.
view_args=()
if [ -n "$repo_argument" ]; then
  view_args=("$repo_argument")
fi
repo_info=$(gh repo view "${view_args[@]}" \
  --json nameWithOwner,visibility \
  --jq '.nameWithOwner + " " + .visibility' 2>&1)
status=$?
if [ $status -ne 0 ]; then
  echo "gh-protect: cannot resolve target repo: $repo_info" >&2
  exit 1
fi
# -r keeps any backslashes in the input literal.
read -r repo visibility <<<"$repo_info"

# Compare case-insensitively: gh versions differ on the casing of the
# visibility value ("private" vs the GraphQL enum "PRIVATE").
visibility_lower=$(echo "$visibility" | tr '[:upper:]' '[:lower:]')
if [ "$visibility_lower" = "private" ]; then
  echo "gh-protect: warning: $repo is private — the GitHub Free plan does" \
    "not enforce rulesets on private repos" >&2
fi

# includes_parents=false limits the listing to repo-level rulesets;
# org-level parents do not exist on a personal account, and could not be
# edited from here anyway.
existing_id=$(gh api "repos/$repo/rulesets?includes_parents=false" \
  --jq ".[] | select(.name == \"$ruleset_name\") | .id" 2>&1)
status=$?
if [ $status -ne 0 ]; then
  echo "gh-protect: cannot list rulesets for $repo: $existing_id" >&2
  exit 1
fi

# ~ALL matches every branch, current and future. If blanket protection adds
# friction later (rebase force-pushes to feature branches, deleting merged
# branches), narrow the ruleset by changing ~ALL to ~DEFAULT_BRANCH, which
# tracks the default branch across renames.
ruleset_json=$(cat <<JSON
{
  "name": "$ruleset_name",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {"include": ["~ALL"], "exclude": []}
  },
  "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}]
}
JSON
)

if [ -z "$existing_id" ]; then
  if [ "$should_apply" = true ]; then
    # --input - reads the JSON request body from stdin.
    output=$(gh api --method POST "repos/$repo/rulesets" \
      --input - <<<"$ruleset_json" 2>&1)
    status=$?
    if [ $status -ne 0 ]; then
      echo "gh-protect: failed to create ruleset on $repo: $output" >&2
      exit 1
    fi
    echo "gh-protect: created ruleset \"$ruleset_name\" on $repo — all" \
      "branches now block force pushes and deletion"
    exit 0
  fi
  echo "gh-protect: $repo is not protected — no \"$ruleset_name\" ruleset" \
    "found. Create it in the repo's Settings → Rules → Rulesets (config" \
    "below), or rerun with --apply using Administration write access:"
  echo "$ruleset_json"
  exit 3
fi

# The ruleset exists; fetch it to see whether it matches. Project it down
# to the fields this script manages, so the comparison ignores server-added
# metadata (id, timestamps, links).
live_json=$(gh api "repos/$repo/rulesets/$existing_id" --jq \
  '{name, target, enforcement, conditions,
    rules, bypass_actors: (.bypass_actors // [])}' 2>&1)
status=$?
if [ $status -ne 0 ]; then
  echo "gh-protect: cannot fetch ruleset $existing_id on $repo:" \
    "$live_json" >&2
  exit 1
fi

expected_normalized=$(normalize_json <<<"$ruleset_json")
live_normalized=$(normalize_json <<<"$live_json")
if [ "$live_normalized" = "$expected_normalized" ]; then
  echo "gh-protect: $repo is protected — ruleset \"$ruleset_name\"" \
    "matches the expected config"
  exit 0
fi

if [ "$should_apply" = true ]; then
  output=$(gh api --method PUT "repos/$repo/rulesets/$existing_id" \
    --input - <<<"$ruleset_json" 2>&1)
  status=$?
  if [ $status -ne 0 ]; then
    echo "gh-protect: failed to update ruleset on $repo: $output" >&2
    exit 1
  fi
  echo "gh-protect: updated ruleset \"$ruleset_name\" on $repo to the" \
    "expected config"
  exit 0
fi

echo "gh-protect: ruleset \"$ruleset_name\" on $repo differs from the" \
  "expected config — possibly intentional. The change --apply would make:"
# -L names the diff sides in place of the temp filenames the process
# substitutions produce.
diff -u -L current -L expected \
  <(echo "$live_normalized") <(echo "$expected_normalized")
exit 3
