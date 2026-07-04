---
description: >-
  Adversarial review of the Claude config: cold subagents hunt defects from
  fixed angles, every claim is re-verified before presentation, and verified
  findings land through chunked user ratification.
disable-model-invocation: true
---

This review earns its findings from two properties an ordinary read-through
lacks: an adversarial stance — each angle hunts for defects on the assumption
that something is broken, rather than grading whether the config reads well —
and independence — several agents reach conclusions separately, so no single
reading becomes an echo chamber. Keep the agents cold and separate; keep
verification and landing in the orchestrating session. Work through the steps in
order.

## 1. Scope

The default scope; anything the user says at invocation overrides it:

- **Target surface**: the global config — `CLAUDE.md`, `rules/`, `skills/`,
  `docs/`, hook wiring, and `settings.json` — plus the working project's
  auto-memory store. Resolve `~/.claude` symlinks to the real dotfiles paths.
- **Lens** — three tests, applied together:
  - **Attention economy**: every loaded rule vies for Claude's attention — one
    shared budget. A rule earns its weight only when the behavior it changes is
    worth the attention it dilutes from every other rule; text that changes no
    behavior fails, and so does a live rule whose value doesn't cover its
    dilution. Rent scales with load class — `CLAUDE.md` bills every message,
    `rules/` only sessions touching matching files, skills and docs almost
    nothing until invoked — so misplacement is itself a defect. The remedy for
    an under-firing rule is a stronger trigger or stakes, never compression:
    length is not the defect, dilution without value is.
  - **Mechanism truth**: what the config claims must be what actually happens —
    hook wiring, globs, permission rules, frontmatter fields. A false claim
    spends attention and misleads every future edit.
  - **Future understandability**: a cold Claude session and the user alike can
    see why each rule exists and edit it safely — maintainer rationale in its
    designated home, no fact duplicated into drift, verified claims
    distinguishable from assumptions.
- **Out of scope**: implementation review of hook and script bodies (style,
  structure, tests), except where a mechanism claim needs checking.
- **Budget**: the full set — every angle below, one agent each.

## 2. Fan out

Launch one cold subagent per angle, in parallel.

- **Dead-rule audit**: read the session logs (`~/.claude/logs/sessions.md`,
  `~/.claude/logs/permission-prompts.log`) and tally which rules the entries
  actually cite; flag rules never cited within the log window.
- **Cold comprehension**: read the entire target surface, then judge each file
  against its runtime loadout — CLAUDE.md alone (every session); a rules file or
  a skill co-loaded with CLAUDE.md only; docs and memory files read on demand.
  Report what a fresh session holding only that loadout would misread —
  ambiguous triggers, directives that cannot be acted on as written — plus a
  mechanical self-containment check: enumerate each file's outbound references
  (named concepts, files, rules) and flag any that do not resolve within the
  loadout. Weigh memory files at instruction grade — nominally background, they
  are followed in practice.
- **Contradiction hunt**: find cross-file disagreements — claims that conflict
  between files, stale references to renamed or deleted items, docs asserting
  behavior the config does not implement, and claims presented as verified fact
  that nothing on the surface substantiates.
- **Attention burden audit**: for each line of always-loaded and path-matched
  config, weigh the behavior it changes against its load class's rent —
  `CLAUDE.md` lines pay most, but a `rules/` or skill line that changes nothing
  still dilutes its loadout. Flag demotion candidates (one load class down, or
  to `docs/`), restatements of what the harness already enforces, and maintainer
  rationale billing at runtime when a notes file is its designated home.
- **Mechanism red-team**: assume documented mechanisms are broken until the
  evidence says otherwise — hook wiring and ordering, glob matching, permission
  allow/deny floors, frontmatter field semantics, script behavior. Hunt for gaps
  and silent failure paths.

Include in every agent prompt: the lens and the out-of-scope boundary from step
1; the paths its angle names, and nothing else about the session; work read-only
and propose no fixes; report each suspected defect as a claim with evidence
(`file:line`), a severity, and the cheapest check that would confirm or refute
it; absence of findings is a valid result — do not pad.

## 3. Verify

Treat every agent claim as a hypothesis, not a finding. Reproduce each with the
cheapest sufficient check — a grep, a windowed read, official docs, or a live
probe. Probes carry standing authorization only when verifiably non-destructive
— read-only commands, throwaway scratch projects, sentinel files; anything else
needs the user's sign-off first. Assign a verdict: CONFIRMED, CALIBRATED (real,
but a different size or shape than claimed), or REFUTED. Only verified claims go
forward; record refutations so the evidence is not re-litigated.

## 4. Cluster

Write the verified findings to a ledger file in the working project (e.g.
`findings.md`) — the ledger is Claude's working scratchpad, not something the
user reads. Group findings by the decision they imply into clusters sized for
one review turn each; when in doubt, split more. Order clusters so broken
mechanics land before restructuring proposals.

## 5. Walk through and land

Present one cluster per turn, at a digestible pace: the verified findings, then
a proposed direction. The user ratifies the direction before any edit; ratifying
a direction is not commit approval — the user reviews the applied diff, then
says commit. Dotfiles commits always need explicit permission for the specific
change. A cluster may also resolve as deferred — the user ratifies queuing the
work instead of landing it; record the deferral for step 6. Record accepted
non-fixes in the ledger so future runs do not re-flag them.

## 6. Close

After the last cluster: move deferred findings into the `tasks.md` of the repo
that owns the reviewed config (the dotfiles repo, for the default surface), note
the run's outcome in the ledger, and remind the user of anything left pending
ratification.
