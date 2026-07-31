# Loaded rules dropped while authoring: case record

Accumulated evidence for one open question in `SKILL.md`'s **Pending
evaluations**: what would make a rule that is loaded, quotable, and directly
applicable actually fire while Claude is writing, rather than after a review or
a user correction surfaces it.

The distinguishing feature is that the rule is present the whole time. In each
case below it was in context, and in several it was quoted accurately once
attention landed on it — the gap is between holding the rule and applying it.

## Scope: what is already handled

An adjacent group of cases — a first draft of a **new file** written against
rules not yet in context — has a mechanical cause and a fix in CLAUDE.md
("Before creating a new file"). Path-matched rules load only when a file is
touched, so a new file's first draft is otherwise authored before its rules
arrive. Those cases are not in this record; adding one here that turns out to be
a new-file case would obscure the distinction.

The cases below are different: the rule was loaded, the file already existed or
the output was chat, and the rule was dropped anyway.

## What a future run should add

Append new instances with the same elements: which rule, what it would have
changed, what was written instead, and how it eventually surfaced. Note in
particular whether the rule was a single directive or enumerated the constructs
it applies to — that distinction decided the 2026-07-30 run's proposal and it is
worth tracking whether it holds up.

## Approaches already rejected

- **"When a rule enumerates the constructs it applies to, walk that enumeration
  item by item."** Rejected: only one case below (the shell comment list) has an
  enumeration inside a rule. The other three are single-directive bullets that
  the wording would not have caught.
- **"Walk the loaded rules file's own bullet list, one bullet at a time."**
  Covers every case, but walking several long rules files against every change
  is costly, and it arguably restates what "as a checklist pass, not by passive
  recall" already asks for — so it may add words without changing behavior.
- **Requiring a cold review instead of inline self-review.** Evidenced elsewhere
  in the log (2026-06-18, where an explicit review pass recovered dropped
  docstring and type rules; 2026-07-28, where inline self-review passed code
  that a cold pass caught and reproduced). Set aside because it improves
  detection after the fact rather than preventing the miss, and because review
  sizing was separately dropped as not rule-worthy.

## Cases

**2026-07-25 · shell script comments.** `shell.md` states, as a literal list,
the constructs that need an explanatory comment: `$0`, `-nt`, `npm --prefix`,
`exec`. A new block was written with prose-level comments only. The self-review
reported a passing style checklist — it had covered the layout rules (80
columns, leading `||`, `$?` on its own line) but never walked the comment list.
The user asked for the comments afterward. The entry's own diagnosis: a
checklist pass that does not walk an enumerated list is recognition-driven, and
misses constructs that look unremarkable in context.

**2026-07-29 · configuration prose.** `claude-configuration.md`'s "Prefer a
concrete instance over a named abstraction" was loaded while Claude proposed
trimming a clause from a CLAUDE.md bullet as redundant. The clause was one of
three enumerated examples, whose value is recognition rather than instruction.
The user restored it, reaching for exactly the rule that had not fired.

**2026-07-14 · tracker note.** `markdown.md`'s "a note is a pointer, not a
summary" was loaded when a tracker note was written that re-narrated a commit.
The user's response was that it does not inform future work. The rule was
dropped at write time and applied only after.

**2026-07-05 · chat output.** CLAUDE.md's Concision rule was loaded for a whole
session and applied to file prose when asked, but not to Claude's own chat
drafts, which ran to multi-paragraph explanations until the user forced a trim —
each round costing a full extra turn. The entry notes the rule was "directly
applicable but under-applied to my own output until made explicit."
