# Global style guide

## Foundational principle: low cognitive load

Every style decision flows from one goal: minimize the mental effort required to read and understand code. In practice this means:

- A reader should grasp any section without scrolling
- Names should communicate their purpose at a glance
- Visual structure should mirror logical structure
- Complexity that doesn't earn its keep should be removed

## Style

- **Line length**: 80 columns; wrap at 80 unless wrapping is clearly more awkward than a longer line
- **Blank lines**: use them to create visual breathing room between logical sections — structure on the page should reflect structure in the logic
- **Naming**: names answer "X what?" — neither terse nor verbose. `page_count` not `count`; not `the_total_number_of_pages`
- **Docstrings**: brief docstring on every top-level definition, even simple ones. "Brief" means efficiently articulated, not just short. Use structured sections (Args, Returns, etc.) only when they genuinely add clarity over prose
- **Inline comments**: at the specific line(s) that do the work, not only in the docstring. The reader should not have to scroll to understand what a branch does
- **Comments describe what is, not what was**: history belongs in git — commit messages, PR descriptions, blame. A comment explaining what changed, what used to be, or why something is no longer the case crowds out the current truth and ages into misinformation
- **TODOs**: write known tradeoffs as TODO comments when not addressing them now, so they aren't lost as mental notes
- **Named helpers**: extract repeated expressions into named constants or helper variables rather than repeating them inline
- **Don't name for the sake of naming**: a name earns its existence by being referenced in multiple places, or by communicating something the value doesn't. A constant used in exactly one place adds a layer of indirection with no payoff — inline it
- **Simplicity**: when two approaches are otherwise equivalent, choose the simpler one
- **Type annotations**: annotate all definitions where the language supports it
- **Factoring**: extract for clarity; don't abstract ahead of actual reuse
- **Use enums for bounded value sets**: when a variable or parameter accepts one of a known, finite set of values, define an enum rather than passing raw literals. This documents what's valid, enables IDE support, and catches invalid values at the call site
- **Don't fail silently**: when a function encounters unexpected state, make the failure visible — raise an exception, log an error, or surface it to the caller. Returning a sentinel value can be the right contract when the caller is expected to handle it, but using one to paper over an error that shouldn't occur hides bugs
- **Include context in error messages**: an error message should contain enough information to diagnose the problem without reproducing it. Include relevant inputs — or an excerpt, if they can be large
- **Prefer instance state over module-level globals**: a module-level object is implicit shared state that can't be overridden in tests without reaching into the module internals. A class that accepts its dependencies through the constructor makes them explicit and replaceable
- **License**: include a license block at the top of every source file. For personal projects, default to MIT: a copyright line followed by an SPDX identifier (e.g. `# Copyright YEAR Name` / `# SPDX-License-Identifier: MIT`, using the language's comment syntax). Default name: `Ilya Sherman (ishermandom@)`
- **Abstract types in API signatures**: prefer abstract collection types over concrete ones in function signatures — the contract should express constraints, not implementation details. Applies to parameters and return types alike.
- **After `Write` on a new file**: path-matched rules don't load until a matching file is Read. `Read` a short excerpt (line 1 suffices), self-review against the loaded rules, and `Edit` if there are gaps.

## Shell

- **Nontrivial logic in named scripts**: prefer a named `.sh` file over an inline pipeline or compound command. Scripts are readable, auditable, and verifiable without running them.
- **Descriptive variables for captured output**: assign command output and exit codes to named variables (`output=$(cmd 2>&1)`, `exit_code=$?`) rather than using them inline. Capture `$?` on the very next line — it is overwritten by every subsequent command.
- **Inline comments on non-obvious flags**: assume the reader rarely writes shell scripts and will not recognize flags like `-quit`, `jq -Rs`, or `2>/dev/null` on sight. Add a brief comment at the specific line explaining what the flag does and why it is used here. Err on the side of over-explaining.
- **Arrays for optional argument lists**: when a set of flags may or may not be passed, use a bash array (`args=()` / `args=(-m "not wip")` / `"${args[@]}"`) rather than a string variable. An unquoted string variable word-splits on spaces, silently breaking multi-word flags.
- **No `set -e`**: avoid `set -e` (exit on error). Many common commands return non-zero in expected situations — `grep` returns 1 when there is no match, for example — and `set -e` will silently exit the script in those cases. Handle errors explicitly instead.
- **Named regex components**: when a regex pattern is non-obvious, break it into named variables — one per logical part — and concatenate them into a `pattern` variable. This is the shell equivalent of a verbose regex: the names document intent without requiring inline comments on the pattern itself.

## Testing

- **Read the guide first**: before any test work, read `~/.claude/docs/testing-guide.md`.
  It defines conventions (DAMP, test input helpers, scripted fakes) that directly
  affect how tests should be written.

## Configuration

- **Global by default**: put hooks, settings, and scripts in `~/.claude/` unless the behavior is genuinely project-specific. Project-scoped config (`.claude/settings.json`, `.claude/hooks/`) is for things tied to one repo — a project-specific toolchain, permissions, or environment variable. When in doubt, ask: would this rule apply in a different project? If yes, it's global.

## Hooks

- **Scope check first**: before wiring a new hook, apply the global-by-default rule above — hooks go in `~/.claude/settings.json` and `~/.claude/hooks/` unless there's a concrete project-specific reason.
- Inlined hook commands should be trivial to understand at a glance. Any nontrivial logic belongs in an external shell script at `.claude/hooks/<name>.sh`.
- **Test hooks run on Stop**: a single turn often has multiple interdependent edits; running tests after each edit produces false failures mid-turn. Wire test hooks to `Stop` so they run once, after all edits have landed.
- **Validate after adding**: after wiring up a new hook, trigger the expected behavior and confirm the hook fires correctly — e.g. introduce a deliberate failure to verify a test hook catches it, then restore.
- **Don't manually run automated hooks**: never propose invoking a linter, type-checker, or test suite that is already wired to a Stop hook — it will run automatically at the end of the turn.

## Interaction style

When gathering structured preferences or exploring a decision with a small,
enumerable option set, use `AskUserQuestion` with multiple-choice options
proactively — don't wait to be asked. Good triggers: tool/library selection,
design tradeoffs, threat-model exercises, preference gathering before writing
a doc or config.

- **Technology currency**: For questions about current best-in-class tools,
  models, or libraries, run a web research agent call before making
  recommendations — training data may be a year or more stale. Good
  triggers: "what's the best X", model/library selection, version
  comparisons.

## Review approach

Work in small, focused increments — each one reads like a pull request with a single clear purpose (add a skeleton, implement one specific piece of functionality, add error handling for one case, etc.).

For each increment:

- Lead with a brief description: what this chunk adds, and what's explicitly deferred to the next
- Explain key decisions and tradeoffs before presenting code
- Wait for approval before moving to the next increment

For bug fixes and refactors where the change is inherently a single unit, apply the same spirit — focused scope, described upfront — without forcing an artificial split.

Before presenting any code, check it against the style rules in this guide.

## Plan documents

Treat plan documents as multi-session work queues by default. Complete the explicitly requested item, then stop. After completing it, suggest a next step only if carrying it out now is meaningfully more efficient with the current live context than saving state and starting fresh — e.g., the work is tightly coupled to what's already in context, or the setup cost in a new session would be significant. Otherwise, say nothing and let the user drive.

## Token and context efficiency

### Standing rules

Every session, without being asked:

- **Never re-read `CLAUDE.md`** — it's injected automatically into every message.
- **Don't `Read` without justification** — before calling `Read`, explicitly
  state why the current context is insufficient. If the file appeared in any
  prior tool result this session, use that; don't fetch again.
- **Prefer `Edit` over `Write` for existing files** — `Edit` sends only the diff;
  `Write` re-sends the whole file. Before doing a full `Write` on an existing
  file, flag it and confirm.
- **Resolve symlinks before editing** — `Edit` and `Write` reject symlink paths,
  wasting a round-trip. Use `readlink -f <path>` to get the real path first.
  Many files under `~/.claude` (including `CLAUDE.md` itself) are symlinks into
  a dotfiles repo — always dereference before editing any path in that directory.
- **Prefer parallel tool calls** when independent.
- **Read files incrementally**: use `grep`/`find` to locate relevant sections,
  then read only those ranges with `offset`/`limit`. For edits, grep for the
  insertion point and read a small window around it — a full file read is rarely
  needed. Read a file in full only when you need to understand interactions
  across distant sections. For multi-file exploration, use the `Explore`
  subagent. Don't read multiple related files in parallel speculatively — start
  with the most likely relevant one and expand only if needed.
- **Cap subagent output**: default to findings only — what's true and why it
  matters for the task at hand. Omit source URLs, framing, and recaps by
  default. Include a URL when it would be needed for a follow-up action in this
  session (fetching, citing, or verifying a specific page). Include additional
  detail or caveats when a finding is surprising, contradicts a prior
  assumption, or would change the approach if omitted. The test: would omitting
  this cause Claude to act on incomplete or misleading information?

### Session-switch guidance

When the session has accumulated context and the user's new request **doesn't
depend on it** (self-contained; could be fully briefed in one sentence without
prior history), say in one sentence: **"This looks self-contained — consider
starting a fresh session."**

When the request **does depend on current context**, say: **"This needs the
current context — staying in this session makes sense."**

### Effort level

When a task arrives, assess complexity and flag in one sentence if the effort
level seems mismatched. Sonnet 4.6 defaults to `high`; `medium` is recommended
for most workloads. Only flag when the mismatch is clear — not on every task.

### On-demand token audit

When asked, read `~/.claude/docs/token-audit.md` for instructions. Don't run unprompted.

## Documentation

- **Concepts over implementation**: Explain what something is trying to achieve and why, not just what it does. This applies everywhere — docstrings, inline comments, and user-facing documentation alike. Implementation details can supplement conceptual framing, but never substitute for it.
- **Lead with goals**: Open with what something is trying to achieve. Constraints and tradeoffs are secondary.
- **Section labels match their content precisely**: A label broader than its section misleads. Narrow the label before broadening the section.
- **Tone**: Matter-of-fact and gentle, not lawyerly or heavy-handed. Avoid language that sounds defensive or thorny.
- **Less is more**: Before explaining something, ask whether the explanation is needed. Often the facts speak for themselves.
- **Factual precision**: Verify physical, operational, and real-world details against the source. Don't paraphrase when exact behavior matters.

# Git

- When pushing to GitHub, always use `origin-https`, not `origin`.
- When already in the correct working directory, run `git` commands directly without the `-C <path>` flag.
- For commit descriptions: keep the subject line to <= 72 chars, and wrap to 80-col for the remaining lines.
