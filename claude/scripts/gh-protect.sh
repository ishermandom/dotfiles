#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Verifies that a GitHub repo's branches carry the protection backstop —
# force pushes and deletion blocked, linear history required, on every
# branch — and reports any gap. Run it whenever a new repo is created.
#
# The check is by function, not by name: it asks whether the repo's active,
# all-branch rulesets together enforce the required rules, regardless of how
# those rulesets are named or split across rulesets.
#
# The script only reads, needing just read access on the repo; it never
# writes a ruleset. Creating one is left to the user via the GitHub UI: a
# token that could write rulesets could also remove them, defeating the
# backstop, so that power stays off the tokens Claude holds. On a gap, the
# script names the missing protections and prints a config to create.
#
# Usage: gh-protect.sh [[HOST/]OWNER/REPO]
#
# Defaults to the current directory's repo. Exit codes: 0 = protected;
# 1 = operational error; 2 = usage error; 3 = not protected (a required
# protection is missing).

# The rule types every branch must be covered by, paired with how each reads
# to the user.
required_rules=(deletion non_fast_forward required_linear_history)

rule_description() {
  case "$1" in
    deletion) echo "block branch deletion" ;;
    non_fast_forward) echo "block force pushes" ;;
    required_linear_history) echo "require linear history" ;;
  esac
}

usage() {
  echo "usage: gh-protect.sh [[HOST/]OWNER/REPO]" >&2
  exit 2
}

repo_argument=""
for argument in "$@"; do
  case "$argument" in
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
# acted on from here anyway.
rulesets_json=$(gh api "repos/$repo/rulesets?includes_parents=false" 2>&1)
status=$?
if [ $status -ne 0 ]; then
  echo "gh-protect: cannot list rulesets for $repo: $rulesets_json" >&2
  exit 1
fi

# Only active, branch-targeting rulesets can protect branches; tag and push
# rulesets, and disabled ones, cannot.
candidate_ids=$(echo "$rulesets_json" | jq -r \
  '.[] | select(.target == "branch" and .enforcement == "active") | .id')

# Collect the rule types enforced on every branch, across all candidates. A
# ruleset counts only if it targets ~ALL — i.e. its rules reach every
# branch, not just some. The list response omits rules and conditions, so
# each candidate needs a detail fetch.
covered_rules=""
for ruleset_id in $candidate_ids; do
  ruleset_rules=$(gh api "repos/$repo/rulesets/$ruleset_id" --jq \
    'select((.conditions.ref_name.include // []) | index("~ALL"))
     | (.rules // [])[].type' 2>&1)
  status=$?
  if [ $status -ne 0 ]; then
    echo "gh-protect: cannot fetch ruleset $ruleset_id on $repo:" \
      "$ruleset_rules" >&2
    exit 1
  fi
  covered_rules="$covered_rules$ruleset_rules"$'\n'
done

# A required rule is satisfied when some all-branch ruleset enforces it.
missing_descriptions=()
for required_rule in "${required_rules[@]}"; do
  # -F fixed string, -x whole-line, -q quiet: an exact match against one
  # collected rule type, so a short name can't match inside a longer one.
  if ! echo "$covered_rules" | grep -Fqx "$required_rule"; then
    missing_descriptions+=("$(rule_description "$required_rule")")
  fi
done

if [ ${#missing_descriptions[@]} -eq 0 ]; then
  echo "gh-protect: $repo is protected — every branch blocks force pushes" \
    "and deletion and requires linear history"
  exit 0
fi

# Join the missing protections into one human-readable clause.
missing_list=$(printf '%s; ' "${missing_descriptions[@]}")
missing_list=${missing_list%; }

echo "gh-protect: $repo is not fully protected — no active all-branch" \
  "ruleset enforces: $missing_list. Create one in the repo's Settings →" \
  "Rules → Rulesets; for example:"

# ~ALL matches every branch, current and future. The name is just a label —
# the check above ignores it. If blanket protection adds friction later
# (rebase force-pushes to feature branches, deleting merged branches),
# narrow the ruleset by changing ~ALL to ~DEFAULT_BRANCH, which tracks the
# default branch across renames.
cat <<JSON
{
  "name": "gh-protect",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {"include": ["~ALL"], "exclude": []}
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "required_linear_history"}
  ]
}
JSON
exit 3
