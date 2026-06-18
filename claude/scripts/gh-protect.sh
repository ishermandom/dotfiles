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
# Authentication: a GH_TOKEN / GH_ENTERPRISE_TOKEN env var or a prior
# `gh auth login` is used when present. Otherwise, for the current repo, the
# token git push saved in the credential store is reused — read-only here, so
# the push token suffices and no separate login is needed.
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

# gh authenticates from GH_TOKEN, GH_ENTERPRISE_TOKEN, or a prior
# `gh auth login`. When none is present — common right after a repo is created,
# before any gh login — fall back to the token that `git push` left in the
# credential store for this repo's remote. This check is read-only, so reusing
# the push token is safe and saves a separate login.
#
# Scoped to the no-argument (current-repo) case: the store keys tokens by the
# exact remote URL git pushed to (with credential.useHttpPath, per-repo tokens
# are split by path), and that URL is readable precisely only from the local
# repo's remotes — not reconstructable from an OWNER/REPO string.
if [ -z "$repo_argument" ] \
   && [ -z "${GH_TOKEN:-}" ] \
   && [ -z "${GH_ENTERPRISE_TOKEN:-}" ]; then
  gh auth status >/dev/null 2>&1
  gh_auth_status=$?
  if [ $gh_auth_status -ne 0 ]; then
    # The first https remote: only https remotes have a credential-store entry,
    # so ssh remotes (git@…) are skipped.
    remote_url=""
    for remote_name in $(git remote 2>/dev/null); do
      candidate_url=$(git remote get-url "$remote_name" 2>/dev/null)
      case "$candidate_url" in
        https://*) remote_url="$candidate_url"; break ;;
      esac
    done

    if [ -n "$remote_url" ]; then
      # Hand git the URL so it parses host/path and applies useHttpPath exactly
      # as push did. GIT_TERMINAL_PROMPT=0 stops an interactive prompt when
      # nothing is stored; 2>/dev/null drops helper chatter. An empty result is
      # fine — it just means no stored token, and the gh call below reports it.
      filled_credential=$(printf 'url=%s\n\n' "$remote_url" \
        | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null)
      # Keep only the filled-in password line — that is the token.
      store_token=$(echo "$filled_credential" | sed -n 's/^password=//p')
      if [ -n "$store_token" ]; then
        export GH_TOKEN="$store_token"
      fi
    fi
  fi
fi

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
