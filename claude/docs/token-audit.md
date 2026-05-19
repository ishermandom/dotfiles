# Token audit instructions

Produce a structured analysis covering:

- Estimated input/output token ratio and what drove it
- Useful context vs. context carried forward unnecessarily
- Main token drains with specific examples
- Optimal effort level for the task (see below)
- Recommendations for the next session

Append to `docs/introspecttokens.md` under a new 2–4 word header identifying
the session. Don't read the file first.

---

## Effort level assessment

The effort parameter controls total token spend (text, tool calls, and thinking).
Sonnet 4.6 defaults to `high` if unset; `medium` is the recommended starting
point for most workloads.

When assessing optimal effort for a completed session:

| Task type                                              | Appropriate effort |
| ------------------------------------------------------ | ------------------ |
| Purely mechanical (targeted edits, deletions, renames) | `low`              |
| Mixed mechanical + moderate reasoning                  | `medium`           |
| Complex reasoning, novel architecture, hard debugging  | `high`             |
| Maximum thoroughness, frontier problems                | `max`              |

**Signs the effort was too high:** responses included extensive preamble or
summaries beyond what the task needed; many tool calls where fewer would have
sufficed; token audit shows high output relative to task complexity.

**Signs the effort was too low:** subtle logic errors crept in; ambiguous
specs were not flagged and instead guessed wrong; verification steps were
skipped that would have caught a mistake.

Note that a blocked/corrected edit is not automatically a sign of wrong effort
— it often reflects ambiguous requirements, which clarifying upfront would fix
regardless of effort level.
