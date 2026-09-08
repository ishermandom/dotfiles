# Prose style guide

How to write and arrange prose so it reads easily on the first pass. Applies
wherever Claude writes prose — including chat responses, comments, docstrings,
commit messages, and documentation.

A principle that speaks of a unit holds at every scale — a clause, a sentence, a
paragraph, and a section each have an opening and a close. Readers expect
material in particular places. Prose that meets those expectations costs almost
nothing to read; prose that defies them spends the reader's attention on
assembling the text rather than on what it says.

- **Open on whose "story" the unit tells** {#topic-position}: the opening words
  set what the reader takes the unit to be about. A unit that opens on a
  subordinate detail makes the reader re-aim once its real subject arrives.
- **Start from material the text has already established** {#given-first}: the
  opening slot also links the unit to what came before, so begin with something
  already named and let the new material follow — a unit that links backward
  gives the new material somewhere to land by providing the relevant context.
  This principle and #topic-position usually select the same opening.
- **End on the new or the weighty** {#stress-position}: closing words carry
  emphasis, so finish on what the unit exists to deliver and move qualifiers and
  conditions earlier.
  - Note: A summary layers on top rather than competing. CLAUDE.md
    #summary-first and #scannable-lists hoist a conclusion into a unit of its
    own, and every unit, the summary included, still runs to its own stress
    position.
- **Keep the subject next to its verb** {#subject-verb}: anything long wedged
  between them leaves the clause unresolved while the reader holds the subject
  open, and reads as an interruption, whatever its importance.
- **Put each clause's action in its verb** {#action-in-verb}: when the real
  action sits anywhere else, the reader assembles the clause in two passes.
  Recurring shapes include the passive (`the fixes are applied by the session`),
  the cleft (`cold rounds are what this skill spends`), the nominalization
  (`perform a comparison of` for `compare`), and `there is`/`there are`.
- **Supply context before the material it frames** {#context-first}: a condition
  before the instruction it governs, a term's definition before its first use, a
  section's purpose before its detail. New material arriving without its frame
  stays unresolved until the frame catches up.
- **Match structural emphasis to substantive emphasis** {#emphasis-match}:
  structure ranks material on its own — a main clause outranks a subordinate
  one, a unit's end outranks its middle. Important material parked in a
  subordinate clause or a parenthetical reads as incidental.

**Apply these as a lens, not a checklist** {#lens-not-checklist}: breaking a
principle deliberately can serve the prose, and writing that already reads
easily needs no repair. Reach for a principle to diagnose a passage that felt
hard to read, not to justify rewriting one that already reads comfortably.
