---
paths:
  - "**/*.bash"
  - "**/*.sh"
  - "**/*.zsh"
  - "**/.zprofile"
  - "**/.zshrc"
---

# Shell script style guide

After any file-modification notice for a shell file this turn, re-read the
target region before composing an `old_string` — the prose reflow hook
(`~/.claude/hooks/reflow_prose.py`) rewraps comment prose right after each Edit
or Write, so match the post-reflow wording, not the pre-reflow snapshot.

- **Use markdown for comment prose**: readable and auto-formatted.
  <!-- How to author comment prose so reflow keeps its structure is a
  cross-language rule, and lives in CLAUDE.md. What reflow leaves alone and
  which markdown shapes survive is written up in `hooks/reflow_prose.py`'s
  module header. -->
- **Run `~/.claude/scripts/quiet-shell.sh` after writing shell**: it formats
  with shfmt and lints with shellcheck. Nothing else will — unlike Markdown,
  JavaScript, and Python, shell code has no edit-time or Stop-time formatter,
  and shfmt never wraps a long line of code. Giving shell a Stop-time check is
  queued: tasks.md #shell-stop-check
- **Avoid `# shellcheck` pragmas**: a suppression usually means either the
  flagged code is wrong or the tool is a poor fit, and a finding local to one
  line usually means that line is the problem — so fix the code rather than
  silence the check. Where a setting genuinely applies project-wide, put it in a
  repo-root `.shellcheckrc`.
- **Prefer decomposing multi-step operations into named variables**: when a
  command sequence mixes concerns — capturing output, checking exit status, or
  chaining transformations — assign each step to a named variable
  (`output=$(cmd 2>&1)`, `exit_code=$?`). Capture `$?` on the very next line —
  it is overwritten by every subsequent command.
- **When an `if` or `while` condition does not fit on one line, name an
  intermediate value rather than wrapping with `\`**: shfmt indents a
  continuation to the same depth as the block body, so a wrapped condition reads
  as part of what it guards. Folding the operands into one named value ahead of
  the `if` — `combined="${primary:-}${fallback:-}"`, then a single `-z` test —
  usually shortens the condition enough to fit.
- **Comment script-isms and opaque commands, not everyday syntax**: assume
  command-line fluency but not script-writing fluency. Comment _script-isms_ —
  constructs met only when writing scripts (positional parameters `$#`/`$@`,
  arrays and `+=`, parameter expansion like `:-` or `${var: -1}`, scoping such
  as `cd` inside `$(...)`) — and _commands or flags whose effect isn't plain
  from their English name_ (`jq -Rs`, `find -quit`). Skip everyday syntax
  (`2>&1`, `2>/dev/null`, `$(...)`, `$PWD`, `$?`, `-eq`) and self-describing
  commands (`git commit`, `realpath`, `tail`). Comment the intent, not the
  mechanics; when unsure, comment.
- **Prefer bash arrays for optional flag lists**: when a set of flags may or may
  not be passed, prefer a bash array (`args=()` / `args=(-m "not wip")` /
  `"${args[@]}"`) over a string variable — an unquoted string variable
  word-splits on spaces, silently breaking multi-word flags.
- **Never use `set -e` (or `set -o errexit`)**: many common commands return
  non-zero in expected situations — `grep` returns 1 when there is no match, for
  example — and `set -e` will silently exit the script in those cases. Handle
  errors explicitly instead.
- **Decompose complex regexes** (general rule in CLAUDE.md): in shell, bind each
  logical part — anchors (`^`/`$`), character classes (`[...]`), groups
  (`(...)`), alternation (`|`) — to its own named variable, concatenated into a
  `pattern` variable. The variable names carry the intent, so the assembled
  pattern needs no inline comment.
