# Prose style guide

How to write prose so it reads easily on the first pass. Applies wherever Claude
writes prose — including chat responses, comments, docstrings, commit messages,
and documentation.

Readers expect material in particular places. Prose that meets those
expectations costs almost nothing to read; prose that defies them spends the
reader's attention on assembling the text rather than on what it says. A
principle that speaks of a unit holds at every scale — a clause, a sentence, a
paragraph, and a section each have an opening and a close.

- **Open on whose "story" the unit tells** {#topic-position}: the opening words
  set what the reader takes the unit to be about. A unit that opens on a
  subordinate detail makes the reader re-aim once its real subject arrives.
- **Start from material the text has already established** {#given-first}: begin
  with something already named and let the new material follow. Established
  material does double duty — it ties the unit back to what came before, and it
  frames the new material arriving next.
- **Close on what deserves emphasis** {#stress-position}: a unit's emphasis
  lands at its close. Readers intuitively sense when a unit is ending, and give
  extra weight to whatever arrives there, so finish on what the unit exists to
  deliver.
  - There are two dangers to watch out for: Closing on self-evidently less
    important material forces the reader to hunt for what to emphasize. Closing
    on material that merely seems weighty is even worse — the reader takes that
    material as the point and reads on, never noticing that the real point went
    past unmarked.
  - Note: Where the words before a colon or semicolon could stand as a sentence
    on their own, they close as though the sentence ended there. Count one place
    to close at the end and one at each such mark; a sentence runs too long when
    more of its material deserves emphasis than it has places to close.
  - Note: Units nest without competing for emphasis. A list can fill the close
    of the sentence introducing it while each list item still internally closes
    on its own. CLAUDE.md #summary-first and #scannable-lists hoist a conclusion
    into a unit of its own on the same principle.
- **Keep a verb next to its subject, object, and particle** {#subject-verb}:
  anything long wedged into one of those bonds keeps the clause unresolved while
  the reader holds it open. However important that material is, it reads as an
  interruption. `leave sections the change doesn't touch alone` strands the
  particle five words from its verb.
- **Put each clause's action in its verb** {#action-in-verb}: when the real
  action sits anywhere else, the reader assembles the clause in two passes.
  Recurring shapes include the cleft (`cold rounds are what this skill spends`),
  the nominalization (`perform a comparison of` for `compare`), and
  `there is`/`there are`.
  - Note: `there is`/`there are` earns its place where existence is the point —
    `there are two dangers` buries no action. Count it against this principle
    only where a real action sits in a noun instead, as
    `there is a need to validate input` does for `validate input`.
  - Note: A passive verb still carries its action, so this principle does not
    turn on voice. #topic-position and #given-first constrain which noun takes
    the subject slot.
- **Supply context before the material it frames** {#context-first}: a condition
  before the instruction it governs, a term's definition before its first use, a
  section's purpose before its detail. New material arriving without its frame
  stays unresolved until the frame catches up.
- **Match structural emphasis to substantive emphasis** {#emphasis-match}:
  structure ranks material, regardless of what the writer intended. For example,
  a main clause outranks a subordinate one, and a unit's end outranks its
  middle. Important material reads as incidental when it is parked in a
  subordinate clause or a parenthetical.

**Apply these as a lens, not a checklist** {#lens-not-checklist}: breaking a
principle deliberately can serve the prose, and writing that already reads
easily needs no repair. Before rewriting, name what the passage makes the reader
hold in memory or do twice. When the existing prose has no concrete cost, no
rewrite is needed.
