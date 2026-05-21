---
paths:
  - "**/*.sh"
---

# Shell script style guide

- **Prefer decomposing multi-step operations into named variables**: when a
  command sequence mixes concerns — capturing output, checking exit status, or
  chaining transformations — assign each step to a named variable
  (`output=$(cmd 2>&1)`, `exit_code=$?`). Capture `$?` on the very next line —
  it is overwritten by every subsequent command.
- **Always comment non-obvious flags**: when a flag's effect isn't obvious from
  its name alone — like `find -quit`, `jq -Rs`, or `2>/dev/null` — add a brief
  inline comment explaining what it does and why it's used here. When in doubt,
  add the comment.
- **Prefer bash arrays for optional flag lists**: when a set of flags may or may
  not be passed, prefer a bash array (`args=()` / `args=(-m "not wip")` /
  `"${args[@]}"`) over a string variable — an unquoted string variable
  word-splits on spaces, silently breaking multi-word flags.
- **Never use `set -e` (or `set -o errexit`)**: many common commands return
  non-zero in expected situations — `grep` returns 1 when there is no match, for
  example — and `set -e` will silently exit the script in those cases. Handle
  errors explicitly instead.
- **Prefer decomposing complex regexes into named components**: when a regex
  contains two or more distinct components — anchors (`^`/`$`), character
  classes (`[...]`), groups (`(...)`), or alternation (`|`) — break it into
  named variables, one per logical part, concatenated into a `pattern` variable.
  The names document intent without requiring inline comments on the pattern
  itself.
