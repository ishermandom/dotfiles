# Experiments: proofread

Method and raw results for measurements run against this skill's check. The
verdict each one reached lives in `notes.md`; this file holds what would be
needed to re-run or audit the measurement.

## Does a persona change what the pass finds? {#persona}

Verdict in `notes.md` #no-persona.

### Question

Whether giving the agent a named professional perspective shifts the findings
themselves, or only the way they are narrated.

### Design

**Corpus**: `claude/docs/design.md` lines 44-178 — the `## Architecture` section
from its heading through the end of `### Hooks`, about 1,300 words. Chosen over
the smaller `skills/deep-review/SKILL.md` because that file had already been
through three proofreading passes, risking a floor effect where both arms find
nothing.

**Arms**: control is the check as `SKILL.md` #launch gives it, followed by the
scope and format block below — 399 words in all. Persona is the same prompt with
the block at #persona-text prepended, 582 words. The persona arm was assembled
by concatenating the same check file, so the control portion is byte-identical
in both.

**Replication**: three runs per arm, six total. Replication is what supplies the
control-to-control variance band; without it there is no yardstick for judging
whether a between-arm difference exceeds ordinary run-to-run spread.

**Controls**: same model (Opus) for every run, identical scope and output
format, runs launched independently with no shared context.

**Blinding**: findings pooled and stripped of arm labels before the user rated
them; arms unblinded only after rating.

**Pre-registered outcomes**, fixed before the runs:

- _Helps_ — the persona arm surfaces passages control misses at a rate above the
  control-to-control variance band, and its unique findings survive blind rating
  about as well as the shared ones.
- _Narration only_ — the passage sets overlap within that variance band.
- _Hurts_ — the persona arm's unique findings rate materially worse.

### Two mechanics worth repeating

**Launch the arms as direct subagents, not by invoking `/proofread`.** The skill
a session runs resolves through `~/.claude/skills` to the main checkout, so a
worktree's edited copy is not the one that would run — see
`rules/claude-configuration.md` #worktree-live-validation. Passing the check
text straight to the agent also removes the skill wrapper as a confound.

**Point the agents at the main checkout's copy of the corpus.** A worktree path
carries the worktree's name, which can hint to the agent what is being tested.
Reading the file at its main-checkout path keeps that out of view while still
loading the path-matched rules the check depends on.

### The persona text, verbatim {#persona-text}

Prepended above the check's opening line.

```text
You are a senior technical writer, brought in to edit technical material
written by people too close to it to see how it reads.

Three levels of editing are in scope, and the first two are where the work is:

- Structural editing — the order in which material arrives, and where the
  emphasis falls.
- Line editing — clarity, flow, and word choice at the sentence and paragraph
  level.
- Copy editing — grammar, punctuation, consistency, terminology, references
  that no longer resolve. The floor of the job, not the work.

Developmental editing — whether the content is right and complete — is out of
scope. That judgment belongs to the author.

The judgment that matters is never about your own reading. An editor works by
modeling one particular other reader: someone meeting this material for the
first time, without the context its authors carry. Report where that reader
slows down, backs up, or finishes a passage still holding a question the text
left unanswered.

The style rules already in context govern this material. Where they differ
from general editorial practice, they win.
```

### The scope and format block, verbatim

Appended to both arms, so it discriminates nothing. The check alone says
"changed lines", which needs a definition when the target is a line range rather
than a diff; the fixed format is what makes findings comparable across runs by
the passage they point at.

```text
## Scope

The file under review is
`/Users/Shared/code/dotfiles/claude/docs/design.md`.

Treat lines 44-178 as the changed lines — the `## Architecture` section, from
its heading through the end of `### Hooks`. Read the whole file for context,
but report findings only on lines 44-178.

## Output format

Report each finding in exactly this format, and write nothing else:

FINDING
Lines: <line number or range>
Quote: <the exact text at issue, verbatim, kept to one sentence or less>
Problem: <one sentence naming what the reader stumbles on>
Fix: <the concrete proposed edit>
```

### Results

Findings per run — control 37, 28, 31 (mean 32.0); persona 27, 32, 30 (mean
29.7). Each arm's own spread exceeds the 2.3 between-arm gap.

Roughly 45 distinct passages across all six runs: 33 shared, 7 control-only, 5
persona-only. Union of the three control runs, 40 passages; of the three persona
runs, 38.

Passages drawing a finding from all six runs: 57-58, 68-69, 75-77, 80-81, 83-85,
86, 93-94, 113-115, 115-116, 131-133, 136-139, 140, 145-146, 153-155, 157-159,
160-162, 171-173, 177-178.

Control-only passages: 71, 92, 101-102, 117-118, 125-127, 134-135, 165.
Persona-only: 90-91, 106, 130, 165-167, 176-177.

Per-run passage lists, for re-deriving the variance band:

- control-1: 54, 57-58, 62, 68-69, 71, 75-77, 78, 80-81, 82-83, 83-85, 86,
  87-88, 92-93, 93-94, 101-102, 103, 110-111, 113-115, 115-116, 125-127,
  131-133, 134-135, 136-137, 137-139, 140, 144-146, 146-149, 150-151, 153-155,
  158-159, 160-161, 163-164, 165, 169, 172-173, 173-174, 177-178
- control-2: 57-58, 62-63, 68-69, 75-77, 80-81, 82-83, 83-85, 86, 93-94,
  101-102, 103-104, 110-111, 113-115, 115-116, 132-133, 136-139, 140-141,
  145-146, 146-149, 152-155, 157-159, 160-162, 163-164, 168-169, 171-173,
  171-174, 176, 177-178
- control-3: 48-54, 57-58, 62-63, 68-69, 75-77, 80-81, 82-83, 83-85, 86, 87-88,
  92, 93-94, 104-105, 110-111, 113-114, 115-116, 117-118, 132-133, 136-137, 140,
  145-146, 150-151, 153-154, 158-159, 161, 163-164, 168-169, 170, 171-172, 173,
  175, 177-178
- persona-1: 48-54, 57-58, 68-69, 75-77, 78, 80-81, 82-83, 83-85, 86, 92-93,
  103, 106-107, 113-115, 116, 132-133, 136-139, 140, 145-146, 153-155, 157-159,
  161, 167-169, 171, 172-173, 173, 175, 178
- persona-2: 48-54, 54, 57-58, 68-69, 75-77, 80-81, 81-83, 83-85, 86, 86-88,
  92-94, 102, 106, 110-111, 113-115, 115-116, 130, 130-132, 136-139, 140-141,
  145-146, 146-149, 150-151, 153-155, 158-159, 160-162, 163-164, 170, 172-173,
  173-174, 175-176, 177-178
- persona-3: 58, 62-63, 68-69, 75-77, 78, 80-81, 83-85, 86, 86-88, 90-91, 93-94,
  103, 110-111, 113-115, 115-116, 132-133, 136-139, 140, 145-146, 153-155,
  158-159, 160-161, 163-164, 165-167, 171-172, 173, 171-175, 175-176, 176-177,
  178

### The blind rating

Six passages every run had flagged, each offering one control-arm rewrite
against one persona-arm rewrite, order shuffled per pair. The user picked the
better of each without knowing which was which.

| Passage | Arm shown as A | Arm shown as B | Picked  | Margin                                         |
| ------- | -------------- | -------------- | ------- | ---------------------------------------------- |
| 68-69   | control-3      | persona-3      | persona | mild                                           |
| 113-115 | persona-2      | control-1      | persona | "more concrete"                                |
| 115-116 | persona-2      | control-3      | control | very mild                                      |
| 136-139 | control-3      | persona-3      | control | on one word; liked persona's clarity otherwise |
| 153-155 | persona-2      | control-2      | persona | —                                              |
| 160-162 | control-2      | persona-2      | persona | —                                              |

Persona took four of six. Under a fair coin that happens about a third of the
time, and two of the four were hedged, so the comparison neither supports nor
rules out a quality effect at this sample size.

### Limitations

**The quality axis is undersampled.** Six pairs cannot resolve a small
difference in rewrite quality. More runs were not spent on it because a small
edge in drafting weighs less than coverage; `notes.md` #no-persona holds why.

**Prompt length is confounded with the persona.** The persona arm carries 183
more words, so an effect could have come from added emphasis rather than from
the perspective. Left uncontrolled deliberately, since the practical question is
whether the modified check performs better, not why. A third arm in which the
persona replaces the check's existing override clauses would hold length closer,
and was not run once the persona showed no effect on what was found.

**No answer key.** Past commits that applied proofreading findings record what a
control-arm pass found and the user accepted, so scoring against them would
reward agreement with control and penalize exactly the divergence under test.
Precision therefore rests on the blind rating alone.
