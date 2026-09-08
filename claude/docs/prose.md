# Prose style guide

How to write prose so it reads easily on the first pass. Applies wherever Claude
writes prose — including chat responses, comments, docstrings, commit messages,
and documentation.

Readers expect material in particular places. Prose that meets those
expectations costs almost nothing to read; prose that defies them spends the
reader's attention on assembling the text rather than on what it says. A
principle that speaks of a unit holds at every scale — a clause, a sentence, a
paragraph, and a section each have an opening and a close. Units nest without
competing: for example, a paragraph opens and closes, and so does every sentence
inside it.

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
  - Note: Front-loading a conclusion does not contradict this principle.
    CLAUDE.md #summary-first and #scannable-lists hoist the conclusion into a
    unit of its own, and that unit closes on its own payload.
- **Give each emphatic point its own close** {#close-per-point}: a sentence has
  one place to close at its end, plus one wherever the words before a break —
  for example, a colon, a semicolon, or a dash — could stand as a sentence on
  their own. A sentence carrying more emphatic material than it has places to
  close leaves the extra points unmarked, and the reader is left to guess which
  of them mattered.
- **Keep a verb next to its subject, object, and particle** {#subject-verb}: a
  long aside wedged into one of those bonds keeps the clause unresolved while
  the reader holds it open. However important that aside is, it reads as an
  interruption. A modifier that identifies what it attaches to is not an aside:
  `two tasks that edit the same file` names which tasks and costs nothing, where
  `leave sections the change doesn't touch alone` strands the particle apart
  from its verb.
- **Put each clause's action in its verb** {#action-in-verb}: when the real
  action sits anywhere else, the reader assembles the clause in two passes.
  Recurring shapes include the cleft (`cold rounds are what this skill spends`),
  the nominalization (`perform a comparison of` for `compare`), and
  `there is`/`there are`.
  - Note: `there is`/`there are` earns its place where existence is the point —
    `there are two dangers` buries no action. Count it against this principle
    only where the real action gets demoted to make room, as in
    `there is a need to validate input` for `validate input`.
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
