Shared routing logic used by both the `pre-compact` and `wrap-session` skills.
Not a skill itself — a referencing skill `Read`s this file and runs it inline,
then layers its own distinct additions on top. Edit here when the shared logic
itself needs to change; each skill's own file holds only what's distinct to it.

## Durable context routing

Move ambient context — anything worth keeping that currently exists only in this
conversation — into a durable file before it's lost. The categories below are
the common destinations, not an exhaustive list: anything that should persist
and doesn't fit one of them still needs a home.

- **Pending work, next steps, and decisions about them** → the project's
  `tasks.md` (or plan doc): update statuses, add tasks, attach
  `Rationale:`/`Note:` annotations per the plan-document conventions.
- **Approaches tried and abandoned** → a `Note:` on the relevant task, or a
  `[-]` dropped task, so the dead end isn't retried.
- **Findings or constraints that outlive any one task** → the project file a
  reader would consult for that topic (a findings section, README, spec).
- **Anything else that should persist** → whichever existing file most naturally
  holds it.

If a piece of context fits none of the project's existing durable files, propose
a new file — name and scope — and confirm with the user before creating it.

Do not write narrative session reports into project files: narrative belongs in
git history and chat, and a project-local log entry is where context goes to get
stale.

## Debt scan {#debt-scan}

Look over changes made this session for shortcuts taken, cleanups skipped,
`TODO`s left, and concerns raised but not addressed. For each: fix it now if
that's cheap, or log it to `tasks.md` as a task if not. Log synchronously — a
deferred concern not written down this turn is lost.

## Memory routing

See CLAUDE.md `#disprefer-memory` for when auto-memory is the right destination
instead of a tracked file. Hint: auto-memory is rarely the right fit.

## Open questions

Note any fork the conversation left undecided — a choice between approaches, an
unresolved tradeoff, a question waiting on the user — as an `Open question:`
note on the relevant task. Don't resolve the question here — just make sure it
stays visible as open.
