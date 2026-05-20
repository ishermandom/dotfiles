---
paths:
  - "**/*.sh"
---

# Shell script style guide

- **Nontrivial logic in named scripts**: prefer a named `.sh` file over an
  inline pipeline or compound command. Scripts are readable, auditable, and
  verifiable without running them.
- **Descriptive variables for captured output**: assign command output and exit
  codes to named variables (`output=$(cmd 2>&1)`, `exit_code=$?`) rather than
  using them inline. Capture `$?` on the very next line — it is overwritten by
  every subsequent command.
- **Inline comments on non-obvious flags**: assume the reader rarely writes
  shell scripts and will not recognize flags like `-quit`, `jq -Rs`, or
  `2>/dev/null` on sight. Add a brief comment at the specific line explaining
  what the flag does and why it is used here. Err on the side of
  over-explaining.
- **Arrays for optional argument lists**: when a set of flags may or may not be
  passed, use a bash array (`args=()` / `args=(-m "not wip")` / `"${args[@]}"`)
  rather than a string variable. An unquoted string variable word-splits on
  spaces, silently breaking multi-word flags.
- **No `set -e`**: avoid `set -e` (exit on error). Many common commands return
  non-zero in expected situations — `grep` returns 1 when there is no match, for
  example — and `set -e` will silently exit the script in those cases. Handle
  errors explicitly instead.
- **Named regex components**: when a regex pattern is non-obvious, break it into
  named variables — one per logical part — and concatenate them into a `pattern`
  variable. This is the shell equivalent of a verbose regex: the names document
  intent without requiring inline comments on the pattern itself.
