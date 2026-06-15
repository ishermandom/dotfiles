# Maintainer notes: wrap-session

Rationale that informs future editing of this skill but isn't needed to run it.
Not referenced from `SKILL.md` — only `SKILL.md` is injected when the skill
runs, so this companion file costs zero runtime context. System-level design
context lives in `docs/design.md`; this file holds the wrap-session-scoped why.

## Session endings

Sessions should end cleanly: what was completed, what is pending, and any
context worth persisting to future sessions. This is the complement to session
orientation — both ends of the multi-session handoff need to be designed.
`SKILL.md` is the source of truth for the steps and formats; the design
decisions behind them:

- Premature exits are a real risk (the user may close the session the moment the
  task feels done); mitigated by making the skill fast and low-friction, and by
  Claude proactively prompting it when the session appears to be wrapping up.
- The retrospective parts are adversarial by design: assume meaningful
  inefficiencies occurred unless evidence suggests otherwise, prioritize
  identifying avoidable waste over highlighting accomplishments, treat user
  corrections as high-signal, and keep proposed adjustments few, specific, and
  narrowly scoped.
- The closing clear/compact/continue judgment exists because compaction defers
  re-ingestion cost to the next turn rather than eliminating it — ending cleanly
  includes deciding what the next session should inherit.
- A debt scan at wrap surfaces shortcuts taken and concerns deferred before they
  are lost — tied to the session boundary rather than firing per-edit, to fit
  the lighter interactive workflow, with deferrals logged to `tasks.md`
  synchronously because an unrecorded item is a lost one. Findings are triaged
  by _when to act_ — block now / fix before closing / later task / accept — not
  by severity, so the class maps onto the next action; the same axis is meant to
  shape the close-out config review's output.
- The effort-level mismatch flag is the retrospective complement to the
  in-session effort calibration in the global CLAUDE.md: a session run at a
  clearly mismatched effort (high on a trivial task, or the reverse) is surfaced
  at wrap as an upskilling note, where the remedy is a setting the user adjusts.
- A structure scan reviews the areas changed this session for how easy the file
  structure is for an agent to work in: for the next likely edit there, how much
  must an agent read, infer, edit, and validate, and how much is hidden. The
  lens is agent ease-of-use, not human-eye tidiness. Where the structure is
  needlessly hard, the scan proposes a fix rather than prescribing one shape — a
  fixed remedy (e.g. "many small files plus an index") was considered and
  rejected as over-prescription: it can itself fight bounded context, since
  over-splitting adds discovery and coordination cost and a small project's one
  well-named file is often the most bounded thing. Distinct from the step-4
  config-size check, which measures token cost rather than edit-boundedness;
  findings route by the same timing axis as the debt scan.

## Session log

A single global file (`~/.claude/logs/sessions.md`) accumulates one entry per
session, appended by the skill — one file across all projects, since
distillation reads one place and efficiency patterns are rarely
project-specific. `SKILL.md` is the source of truth for the entry format. The
design decisions:

- Entries pair qualitative sections with a scope line of countable events; the
  measurement rationale is under Token and context-health quantification below.
- The Rules section doubles as the citation data rule governance consumes —
  whether each loaded artifact earned its tokens, and whether a rule that should
  have fired was silently dropped. A drop is visible only in the live session,
  so wrap-session detects and records it; distillation works from the log and
  aggregates that signal across sessions but cannot recover a drop that went
  unrecorded. This splits the labor: live detection at wrap, the cross-session
  verdict at distillation — which hardens a persistent violator to a hook only
  after a few sessions confirm it won't hold in CLAUDE.md. One session is
  citation data, not a verdict.
- The entry size budget is a forcing function for selectivity, not a target, and
  all counts are directional diagnostics — never targets to optimize.
- Distillation runs as a manual skill, on demand; each run appends a marker
  entry, and the skill suggests a run once ~10 entries have accumulated past the
  last marker.

## Token and context-health quantification

The system-level efficiency model lives in `docs/design.md` (Token and context
health). The measurement machinery — how the session log records token cost — is
wrap-session-scoped and lives here. The hook `hooks/session-tokens.py` (whose
read-only `--print` mode feeds the wrap-time reflection) and `SKILL.md` are the
operative sources for the formats.

Each session log entry carries two kinds of numbers. Claude declares a session
type (coding / debug / refactor / planning / explore) and counts events from the
conversation — files modified, correction turns, file reads — which only
conversation judgment can produce. Token counts are automated: a SessionEnd hook
sums the four raw API usage counters (input, output, cache-write, cache-read)
from the session's transcript and subagent transcripts and writes them into the
entry, matched via a session-id marker that wrap-session stamps; a session with
no wrap entry gets a minimal type-less "stats-only" entry instead.

Decisions and rationale:

- Raw counters, not derived ratios, go in the log: ratios (per file changed,
  against per-type baselines) derive at distillation time from the raws plus the
  event counts, so metric definitions can evolve without invalidating history.
- The counters proxy different costs: output ≈ work performed; input +
  cache-write ≈ new context ingested; cache-read ≈ context size summed over API
  calls — the closest available proxy for attention load.
- Hook-written at SessionEnd rather than skill-written at wrap time:
  end-of-session counts include the wrap conversation itself and any tail, and
  the hook is handed the transcript path instead of guessing it.
- Attribution is per-session, with session ≈ task (session hygiene pushes one
  task per session).
- Known limitations: SessionEnd does not fire on a crash or kill, so those
  sessions go uncounted; stats-only entries carry no session type, so they sit
  outside per-type baselines; no minimum-size floor on stats-only entries —
  every `/clear` segment gets one — so add a floor if distillation finds them
  noisy.
- Hook diagnostics (malformed transcript lines, usage fields outside the
  expected schema) append to `~/.claude/logs/session-tokens.log` — stderr from a
  SessionEnd hook is lost once the session ends. The schema guard exists because
  a renamed counter would otherwise silently zero the totals.

Once ~5 sessions of a type exist, compare against the per-type rolling baseline
and treat >1.5× baseline as a question to investigate, not a verdict.
Within-type variance is harder to game; raw counts are gameable and not worth
targeting.
