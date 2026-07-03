---
paths:
  - "**/*.bash"
  - "**/*.sh"
  - "**/*.zsh"
  - "**/.zprofile"
  - "**/.zshrc"
---

# Shell script style guide

- **Prefer decomposing multi-step operations into named variables**: when a
  command sequence mixes concerns — capturing output, checking exit status, or
  chaining transformations — assign each step to a named variable
  (`output=$(cmd 2>&1)`, `exit_code=$?`). Capture `$?` on the very next line —
  it is overwritten by every subsequent command.
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
