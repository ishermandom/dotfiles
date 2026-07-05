# config-review maintainer notes

Editing-time rationale and open design threads for the `config-review` skill.
Never referenced from `SKILL.md`; read when editing the skill.

## Origin and evidence

The skill captures the adversarial round run 2026-07-03 against the global
config (session ledger: `claude-rules-architecture/findings.md`, "Adversarial
round" section). The premise it encodes was tested directly: two sympathetic
review rounds converged having found little, then the adversarial fan-out
surfaced ~30 verified defects — hook-ordering assumptions that were false,
permission-floor gaps, globs that never matched, docs asserting unimplemented
behavior. Sympathetic review graded prose; cold agents found wiring.

## Design rationale

- **Cold agents, by construction**: the fan-out step tells agents nothing about
  the session. That buys independence — each agent concludes from the artifacts
  alone, and separate agents cannot echo one another's (or the session's)
  assumptions — and makes the adversarial stance easier to hold, with no
  investment in the config under review. The orchestrator keeps the jobs
  independence doesn't help: verification and landing.
- **One comprehension agent, not one per surface**: the first run split
  comprehension three ways (CLAUDE.md; rules/; skills/). The split loses on
  reflection: it hard-codes a surface list that missed `docs/` and would miss
  future directories, it buys no independence (agents reading disjoint files
  cannot cross-check each other), and it false-positives on legitimate
  cross-surface references unless each agent is handed its co-load. The one real
  thing enforced isolation bought — a reader who cannot resolve a dangling
  reference — is approximated mechanically instead: the agent enumerates each
  file's outbound references and checks them against that file's runtime
  loadout. The whole surface is a few thousand lines, well within one agent's
  comfortable read; split by loadout only if the config outgrows that.
- **Memory files weigh at instruction grade**: the store nominally loads as
  non-authoritative background, but its observed effect is close to
  authoritative — recalled memories are followed like instructions. Validation
  stakes follow observed weight, not nominal status.
- **Run state and cross-run memory live beside the skill, split by lifetime**:
  `ledger.md` is the run-scoped scratchpad — walkthrough state must survive
  compaction and session breaks, which the first run's ledger did — deleted at
  close and gitignored. `accepted-tradeoffs.md` is the durable list of defects
  accepted as-is, consulted by the verify pass so runs never re-litigate them.
  Storing either in the working project would strand it: the next run may start
  from a different project (the first run's ledger sits in a repo since
  archived), while files beside the skill are findable from anywhere.
- **Verify pass is mandatory, not optional polish**: in the first run the
  orchestrator refuted 2 agent claims outright (one via a live probe that beat
  the agent's static forensics) and cut a third down to size. Agent reports are
  hypotheses with confident prose; presenting them unverified would hand the
  user false findings.
- **Agents read-only, probes orchestrator-side**: live probing needs the
  non-destructive judgment call and accountability in the main session. Probes
  carry standing authorization rather than a per-run ask because the
  verifiably-non-destructive constraint is itself strict — anything outside it
  still needs the user's sign-off, stated at the point of use in step 3. The
  read-only-ness of agents is by instruction, not enforcement — the `Explore`
  agent type still carries Bash — so the permission mode is the backstop.
- **`disable-model-invocation: true`**: a full run fans out five agents — the
  user controls timing and spend. Field semantics verified against the Claude
  Code docs (2026-07-03): user-only invocation, excluded from Claude's skill
  list, not preloaded into subagents, and (v2.1.196+) not runnable from a
  scheduled task.
- **Inline, not `context: fork`**: steps 4–6 are an interactive walkthrough with
  per-cluster ratification; a forked context would sever exactly the
  conversation the skill exists to have. Matches the design.md guidance that
  interactive skills run inline.
- **No scoping interview**: the skill is the canonical recipe — invoking it is
  consent, so step 1 states the scope instead of asking about it, and overrides
  ride the invocation message.
- **The lens is spelled out, not compressed**: a one-phrase lens ("attention
  management plus future understandability") proved too abstract to hand agents
  verbatim — each unstated nuance was a misreading waiting to happen. The
  expansion pins them: the attention economy is Claude's only (the user's
  attention shapes walkthrough pacing, not the lens); the test is dilution
  versus value, so a rule that does change behavior can still fail; mechanism
  truth is a leg every angle applies, not the red-team's alone; and
  understandability serves a cold Claude session and the user as owner equally.
- **Memory store in the default surface**: the first run found real drift there
  (superseded regimes, dangling references), and auditing it is cheap.
  Per-project `.claude/` configs stay an opt-in scope extension — their
  relevance varies run to run.
- **Division of labor with distill**: the citation audit's single home is the
  dead-rule angle here — the audit never ran organically inside distill's flow,
  and one mechanism beats two. Distill keeps the sensing role: it reminds the
  user to run `/config-review` when never-cited rules accumulate, and escalates
  repeated config-size complaints into a proposal item with the same call to
  action. The signals differ — dead rules are unused, while size hurts even when
  every rule is used. Nothing distill sees escapes the handoff: the dead-rule
  angle reads distill's own input log (`sessions.md`) plus the
  permission-prompts log.
- **No sympathetic pre-pass**: deliberately omitted. The evidence above says its
  marginal yield after convergence is near zero; a user who wants one can run
  `/code-review` separately.
- **Landing protocol restates the working-style rules** (direction ≠ commit
  approval, dotfiles commits need explicit permission) even though they also
  live in memory and CLAUDE.md: the walkthrough is exactly where those rules
  historically slipped, and a skill body is the one surface guaranteed loaded
  during the walkthrough.

## Frontmatter: the description's `>-` block scalar is load-bearing

The description contains `config: cold`, which is a silent frontmatter-voiding
parse error as a plain scalar — the rule lives in the Gotchas section of
`claude-configuration.md`, and this skill is where it was hit live. Keep the
`>-`.

## Refinement brainstorm

Ideas considered but not built — most want a second run's evidence first:

- **Budget tiers**: a `light` argument running only the two cheapest angles
  (contradiction hunt + burden audit) for between-major-churn checkups, with
  full fan-out reserved for occasional deep runs. Premature until a second run
  gives real cost data.
- **Prompt templates as skill files**: once per-angle prompt wording stabilizes,
  move it into files beside `SKILL.md` (loaded by the fan-out step, not injected
  at skill start) so runs stay comparable and the skill body stays lean. After
  one run, wording is not yet stable.
- **Per-angle precision tracking**: log confirmed/calibrated/refuted counts per
  angle across runs; an angle whose claims keep getting refuted is spending
  verification budget without paying — retire or reshape it.
- **Sixth angle — permission-surface floor audit**: in the first run the
  `git branch:*` hole came from the mechanism red-team as a side catch. A
  dedicated agent enumerating allow-rule prefixes against destructive spellings
  might find more, systematically.
- **Memory-store angle**: the store is already in the default target surface,
  covered by the contradiction hunt (which found the first run's memory-hygiene
  defects) and by the comprehension agent at instruction grade. If drift there
  keeps outpacing that coverage, a dedicated angle with the store's index and
  files as its sole surface may pay.
- **Cadence trigger**: wrap-session or distill could suggest a run when config
  churn accumulates (e.g. N dotfiles commits touching `claude/` since the last
  run). Distill already prompts on two log-derived signals (never-cited rules,
  repeated size complaints); a churn-based trigger would be a third, keyed to
  commits rather than the log.
