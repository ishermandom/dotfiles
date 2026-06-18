#!/usr/bin/env python3
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Append stdin to the wrap-session session log. wrap-session calls this in place
# of a raw `cat >> ~/.claude/logs/sessions.md <<'EOF'` heredoc.
#
# Why a script rather than the redirect: Claude Code gates any Bash command that
# redirects output to a path outside the workspace, so the raw `>>` append
# prompts every time regardless of the command allow list. Here the write
# happens inside the script, so the Bash command carries no out-of-workspace
# redirect — it can be allowlisted by command pattern
# (Bash(~/.claude/scripts/append-session-log.py:*)) and never prompts. Because
# the target is hardcoded, allowlisting grants no write scope beyond this one
# file.

import sys
from pathlib import Path

SESSION_LOG = Path('~/.claude/logs/sessions.md').expanduser()


def main() -> None:
  """Append everything on stdin to the session log, creating it if absent."""
  entry = sys.stdin.read()
  with SESSION_LOG.open('a', encoding='utf-8') as log:
    log.write(entry)


if __name__ == '__main__':
  main()
